# frozen_string_literal: true

require 'bundler/setup'
require 'csv'
require 'date'
require 'dry/cli'
require 'etc'
require_relative 'parser'
require_relative 'reporter'
require 'time'

EPOCH_START = Date.new(1970, 1, 1)
Y2K38_LIMIT = Date.new(2038, 1, 19)

def get_time(start, end_date)
  start_time = start ? parse_date!('start', start) : EPOCH_START
  end_time   = end_date ? parse_date!('end', end_date) : Y2K38_LIMIT
  [start_time, end_time]
end

def parse_date!(label, val)
  Date.iso8601(val)
rescue ArgumentError
  raise "Invalid #{label} date format. Expected ISO8601 (YYYY-MM-DD)."
end

def tty_table(headers, rows, title)
  puts "\n#{title}"
  table = TTY::Table.new(headers, rows)
  puts table.render(:unicode, padding: [0, 1])
  [headers, rows]
end

# Added CLI module to match AlcesSacct::CLI::Commands
module AlcesSacct
  module CLI
    module Commands
      extend Dry::CLI::Registry

      class Report < Dry::CLI::Command
        desc 'Report based on flags sent to the cli'

        option :csv,       aliases: ['-c'], type: :string, desc: 'Output CSV filename'
        option :end,       aliases: ['-E'], type: :string, desc: 'Endtime in ISO format'
        option :partition, aliases: ['-p'], type: :string, desc: 'Filter by partition'
        option :start,     aliases: ['-S'], type: :string, desc: 'Starttime in ISO format'
        option :state,     aliases: ['-s'], type: :string, desc: 'States as comma seperated list'
        option :user,      aliases: ['-u'], type: :boolean,
                           desc: 'Filter by user (defaults to current user if no username specified)'

        def call(**opts)
            inputs = clean_inputs(**opts)
            jobs = Parser.new.fetch(inputs)

            reporter = SacctReporter.new(jobs)

            user_specified      = opts[:user] && opts[:user] != 'none'
            partition_specified = opts[:partition] && opts[:partition] != 'all'

            # Table Headers matching SacctReporter#build_rows outputs
            grouped_headers = [
                'Jobs', 'Mean CPU', 'Mean Mem', 'Med CPU',
                'Med Mem', 'Queue Med', 'Queue P95', 'Outcomes', 'Exit Summary'
            ]

            headers_with_name = ['Group'] + grouped_headers

            if user_specified && partition_specified
                # 1. Single User & Single Partition
                m = reporter.metrics
                return puts "No jobs found for specified user and partition." unless m

                row = [[m[:count], m[:mean_cpu], m[:mean_mem], m[:med_cpu], m[:med_mem], m[:queue_med], m[:queue_p95], m[:outcomes_str], m[:exit_str]]]
                title = "Summary for User (#{jobs.first&.user}) on Partition (#{jobs.first&.partition})"
                tty_table(grouped_headers, row, title)

            elsif user_specified
                # 2. Single User -> Group by Partition + Overall Total
                display_grouped_report(reporter, jobs, "Partition Summary for User", headers_with_name, grouped_headers, &:partition)

            elsif partition_specified
                # 3. Single Partition -> Group by User + Overall Total
                display_grouped_report(reporter, jobs, "User Summary for Partition", headers_with_name, grouped_headers, &:user)

            else
                # 4. Neither -u nor -p -> Group by User & Partition combination + Overall
                grouped_by_both = jobs.group_by { |j| "#{j.user} / #{j.partition}" }
                
                # Build rows including the group name at index 0 for display
                rows_with_names = grouped_by_both.filter_map do |group_name, job_list|
                rep = SacctReporter.new(job_list)
                m = rep.metrics
                next unless m

                [group_name, m[:count], m[:mean_cpu], m[:mean_mem], m[:med_cpu], m[:med_mem], m[:queue_med], m[:queue_p95], m[:outcomes_str], m[:exit_str]]
                end

                tty_table(headers_with_name, rows_with_names, "Breakdown by User & Partition")

                # Render Overall Summary
                m = reporter.metrics
                if m
                    overall_row = [[m[:count], m[:mean_cpu], m[:mean_mem], m[:med_cpu], m[:med_mem], m[:queue_med], m[:queue_p95], m[:outcomes_str], m[:exit_str]]]
                    tty_table(grouped_headers, overall_row, "Overall Metrics Summary (All Jobs)")
                end
            end
        end

        private

        def display_grouped_report(reporter, jobs, title, headers_with_name, single_headers, &group_block)
            grouped_jobs = jobs.group_by(&group_block)

            # Include the group label in column 1 for table output
            rows_with_names = grouped_jobs.filter_map do |group_name, job_list|
                rep = SacctReporter.new(job_list)
                m = rep.metrics
                next unless m

                [group_name, m[:count], m[:mean_cpu], m[:mean_mem], m[:med_cpu], m[:med_mem], m[:queue_med], m[:queue_p95], m[:outcomes_str], m[:exit_str]]
            end

            tty_table(headers_with_name, rows_with_names, title)

            # Render Overall total row
            m = reporter.metrics
            if m
                overall_row = [[m[:count], m[:mean_cpu], m[:mean_mem], m[:med_cpu], m[:med_mem], m[:queue_med], m[:queue_p95], m[:outcomes_str], m[:exit_str]]]
                tty_table(single_headers, overall_row, "Overall Total")
            end
        end

        def clean_inputs(**opts)
          start_time, end_time = get_time(opts[:start], opts[:end])
          partition = opts[:partition] && !opts[:partition].empty? ? opts[:partition] : 'all'
          state = opts[:state] && !opts[:state].empty? ? opts[:state] : 'all'
          target_user = parse_user_flag(opts[:user])
          [start_time, end_time, target_user, partition, state]
        end

        def parse_user_flag(user_flag)
          return 'none' unless user_flag

          user_index = ARGV.index { |arg| ['--user', '-u'].include?(arg) }
          next_arg = user_index ? ARGV[user_index + 1] : nil

          if next_arg && !next_arg.start_with?('-')
            next_arg
          else
            current_user
          end
        end

        def current_user
          Etc.getlogin || ENV['USER'] || ENV['LOGNAME'] || Etc.getpwuid(Process.uid)&.name
        rescue StandardError
          ENV['USER']
        end
      end

      register 'report', Report
    end
  end
end