# frozen_string_literal: true

require 'bundler/setup'
require 'csv'
require 'date'
require 'dry/cli'
require 'etc'
require_relative 'parser'
require_relative 'reporter'
require 'time'
require 'tty-table'

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

# Unified display and export function
def render_and_export(headers, rows, title, csv_filename: nil)
  puts "\n#{title}"
  table = TTY::Table.new(headers, rows)
  puts table.render(:unicode, multiline: true) { |r| r.border.separator = :each_row }

  if csv_filename && !csv_filename.empty?
    # Ensure filename ends with .csv
    csv_filename += '.csv' unless csv_filename.end_with?('.csv')

    CSV.open(csv_filename, 'w') do |csv|
      csv << headers
      rows.each { |row| csv << row }
    end
    puts "\nReport exported successfully to: #{csv_filename}"
  end

  [headers, rows]
end

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

          metrics_headers = [
            'Jobs', 'Mean CPU', 'Mean Mem', 'Med CPU',
            'Med Mem', 'Queue Med', 'Queue P95', 'Outcomes', 'Exit Summary'
          ]

          csv_name = opts[:csv]

          if user_specified && partition_specified
            # 1. Single User & Single Partition
            m = reporter.metrics
            return puts "No jobs found for specified user and partition." unless m

            headers = ['User', 'Partition'] + metrics_headers
            row = [[jobs.first&.user, jobs.first&.partition, m[:count], m[:mean_cpu], m[:mean_mem], m[:med_cpu], m[:med_mem], m[:queue_med], m[:queue_p95], m[:outcomes_str], m[:exit_str]]]
            
            out_file = build_csv_name(csv_name, 'user_partition')
            render_and_export(headers, row, "Summary for User (#{jobs.first&.user}) on Partition (#{jobs.first&.partition})", csv_filename: out_file)

          elsif user_specified
            # 2. Single User -> Partitions + Overall Total
            headers = ['Partition'] + metrics_headers
            rows = build_grouped_rows(jobs, &:partition)
            
            # Append overall row
            m = reporter.metrics
            rows << ['overall', m[:count], m[:mean_cpu], m[:mean_mem], m[:med_cpu], m[:med_mem], m[:queue_med], m[:queue_p95], m[:outcomes_str], m[:exit_str]] if m

            out_file = build_csv_name(csv_name, 'user')
            render_and_export(headers, rows, "Partition Summary for User (#{jobs.first&.user})", csv_filename: out_file)

          elsif partition_specified
            # 3. Single Partition -> Users + Overall Total
            headers = ['User'] + metrics_headers
            rows = build_grouped_rows(jobs, &:user)

            # Append overall row
            m = reporter.metrics
            rows << ['overall', m[:count], m[:mean_cpu], m[:mean_mem], m[:med_cpu], m[:med_mem], m[:queue_med], m[:queue_p95], m[:outcomes_str], m[:exit_str]] if m

            out_file = build_csv_name(csv_name, 'partition')
            render_and_export(headers, rows, "User Summary for Partition (#{jobs.first&.partition})", csv_filename: out_file)

          else
            # 4. Neither -u nor -p -> Hierarchical Single Table (overall/overall, overall/partition, user/overall, user/partition)
            headers = ['User', 'Partition'] + metrics_headers
            rows = []

            # 4a. Overall / Overall
            m_all = reporter.metrics
            rows << ['overall', 'overall', m_all[:count], m_all[:mean_cpu], m_all[:mean_mem], m_all[:med_cpu], m_all[:med_mem], m_all[:queue_med], m_all[:queue_p95], m_all[:outcomes_str], m_all[:exit_str]] if m_all

            # 4b. Overall / [Partition]
            jobs.group_by(&:partition).each do |part_name, part_jobs|
              m = SacctReporter.new(part_jobs).metrics
              next unless m
              rows << ['overall', part_name, m[:count], m[:mean_cpu], m[:mean_mem], m[:med_cpu], m[:med_mem], m[:queue_med], m[:queue_p95], m[:outcomes_str], m[:exit_str]]
            end

            # 4c. [User] / Overall  AND  [User] / [Partition]
            jobs.group_by(&:user).each do |user_name, user_jobs|
              # User / Overall
              m_user = SacctReporter.new(user_jobs).metrics
              rows << [user_name, 'overall', m_user[:count], m_user[:mean_cpu], m_user[:mean_mem], m_user[:med_cpu], m_user[:med_mem], m_user[:queue_med], m_user[:queue_p95], m_user[:outcomes_str], m_user[:exit_str]] if m_user

              # User / Partitions
              user_jobs.group_by(&:partition).each do |part_name, up_jobs|
                m_up = SacctReporter.new(up_jobs).metrics
                next unless m_up
                rows << [user_name, part_name, m_up[:count], m_up[:mean_cpu], m_up[:mean_mem], m_up[:med_cpu], m_up[:med_mem], m_up[:queue_med], m_up[:queue_p95], m_up[:outcomes_str], m_up[:exit_str]]
              end
            end

            out_file = build_csv_name(csv_name, 'overall')
            render_and_export(headers, rows, "Unified Workload Summary", csv_filename: out_file)
          end
        end

        private

        def build_grouped_rows(jobs, &group_block)
          jobs.group_by(&group_block).filter_map do |group_name, job_list|
            m = SacctReporter.new(job_list).metrics
            next unless m

            [group_name, m[:count], m[:mean_cpu], m[:mean_mem], m[:med_cpu], m[:med_mem], m[:queue_med], m[:queue_p95], m[:outcomes_str], m[:exit_str]]
          end
        end

        def build_csv_name(base_name, metric_type)
          return nil unless base_name && !base_name.to_s.strip.empty?

          clean_base = base_name.sub(/\.csv\z/i, '')
          "#{clean_base}_#{metric_type}.csv"
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