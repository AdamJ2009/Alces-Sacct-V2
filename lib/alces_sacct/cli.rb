# frozen_string_literal: true

require 'bundler/setup'
require 'date'
require 'dry/cli'
require 'etc'
require 'time'

require_relative 'parser'
require_relative 'reporter'
require_relative 'renderer'
require_relative 'version'

EPOCH_START = Date.new(1970, 1, 1)
NO_FLAG_TODAY = Date.today
NO_FLAG_7_DAYS_AGO = NO_FLAG_TODAY - 7
Y2K38_LIMIT = Date.new(2038, 1, 19)

module AlcesSacct
  module CLI
    # Commands callable in executable
    module Commands
      extend Dry::CLI::Registry

      # Command that generates the report for overall, partition and user
      class Report < Dry::CLI::Command
        desc 'Report based on flags sent to the cli'

        option :csv,          aliases: ['-c'], type: :string,  desc: 'Output CSV filename'
        option :end,          aliases: ['-E'], type: :string,  desc: 'Endtime in ISO format'
        option :limit_time,   aliases: ['-L'], type: :integer, desc: 'Limit time of search in days', default: 90
        option :overall,      aliases: ['-o'], type: :boolean, desc: 'Show overall'
        option :partition,    aliases: ['-p'], type: :string,  desc: 'Filter by partition'
        option :start,        aliases: ['-S'], type: :string,  desc: 'Starttime in ISO format'
        option :state,        aliases: ['-s'], type: :string,  desc: 'States as comma seperated list'
        option :user,         aliases: ['-u'], type: :boolean, desc: 'Filter by user (defaults to current user)'
        option :unknown_user, aliases: ['-U'], type: :boolean,
                              desc: 'Filter strictly for jobs with no user ID/association'

        def call(**opts)
          user_specified, partition_specified, ctx = process(**opts)

          if user_specified && partition_specified
            Renderer.render_single_user_and_partition(ctx)
          elsif user_specified
            Renderer.render_single_user(ctx, opts[:overall])
          elsif partition_specified
            Renderer.render_single_partition(ctx, opts[:overall])
          else
            Renderer.render_unified_summary(ctx, opts[:overall])
          end
        rescue Errno::ENOENT => e
          warn "Error: Unable to locate binary - #{e.message}"
          exit 1
        end

        def get_time(start, end_date, limit)
          start_time = start ? parse_date!('start', start) : NO_FLAG_7_DAYS_AGO
          end_time   = end_date ? parse_date!('end', end_date) : NO_FLAG_TODAY

          # Clamp boundaries
          start_time = [start_time, EPOCH_START].max
          end_time   = [end_time, Y2K38_LIMIT].min

          # Ensure date range respects limit (in days)
          if (end_time - start_time).to_i > limit
            start_time = end_time - limit
          end

          puts "Start time: #{start_time}"
          puts "End time: #{end_time}"

          [start_time, end_time]
        end

        def parse_date!(label, val)
          Date.iso8601(val)
        rescue ArgumentError
          raise "Invalid #{label} date format. Expected ISO8601 (YYYY-MM-DD)."
        end

        private

        def process(**opts)
          inputs = clean_inputs(**opts)
          jobs = Parser.new.fetch(inputs)
          csv_name = Renderer.csv_check!(opts[:csv])
          ctx = { jobs: jobs, reporter: SacctReporter.new(jobs), csv_name: csv_name }

          user_specified      = opts[:user] || opts[:unknown_user]
          partition_specified = opts[:partition] && opts[:partition] != 'all'
          [user_specified, partition_specified, ctx]
        end

        def clean_inputs(**opts)
          # Fixed opts[:limit] to opts[:limit_time]
          start_time, end_time = get_time(opts[:start], opts[:end], opts[:limit_time])
          partition = opts[:partition] && !opts[:partition].empty? ? opts[:partition] : 'all'
          state = opts[:state] && !opts[:state].empty? ? opts[:state] : 'all'

          target_user = resolve_user_target(opts)
          [start_time, end_time, target_user, partition, state]
        end

        def resolve_user_target(opts)
          return 'unknown_only' if opts[:unknown_user]
          return parse_user_flag(opts[:user]) if opts[:user]

          'none'
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

      # Puts version
      class Version < Dry::CLI::Command
        desc 'Print the version'

        def call(*)
          puts "AlcesSacct version #{AlcesSacct::VERSION}"
        end
      end

      register 'report', Report
      register 'version', Version, aliases: ['-v', '--version']
    end
  end
end