# frozen_string_literal: true

require 'bundler/setup'
require 'csv'
require 'date'
require 'dry/cli'
require 'etc'
require_relative 'parser'
require 'time'

EPOCH_START = Date.new(1970, 1, 1)
Y2K38_LIMIT = Date.new(2038, 1, 19)

def get_time(start, end_date)
  start_time = start ? parse_date!('start', start) : EPOCH_START
  end_time   = end_date ? parse_date!('end', end_date) : Y2K38_LIMIT
  [start_time, end_time]
end

# Example definition of parse_date! if it's missing:
def parse_date!(label, val)
  Date.iso8601(val)
rescue ArgumentError
  raise "Invalid #{label} date format. Expected ISO8601 (YYYY-MM-DD)."
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
          output = Parser.new.fetch(inputs)
          #Reporter.new(output)
        end

        private

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