#!/usr/bin/env ruby
# frozen_string_literal: true

# This program is NOT y2k38 compliant, it will fail in 2038

require 'bundler/setup'
require 'csv'
require 'date'
require 'dry/cli'
require 'etc'
require 'lib/alces_sacct/parser'
require 'time'

# Unix Epoch: Jan 1, 1970
EPOCH_START = Date.new(1970, 1, 1)

# Y2K38 Limit: Jan 19, 2038 (32-bit signed integer max epoch offset)
Y2K38_LIMIT = Date.new(2038, 1, 19)

# Universal static functions
def get_time(start, end_date)
  start_time = start ? parse_date!('start', start) : EPOCH_START
  end_time   = end_date ? parse_date!('end', end_date) : Y2K38_LIMIT
  [start_time, end_time]
end

# CLI command register
module Commands
  extend Dry::CLI::Registry

  # Handles pretty printing and csv of reports
  class Report < Dry::CLI::Command
    desc 'Report based on flags sent to the cli'

    option :csv,       aliases: ['-c'], type: :string, desc: 'Output CSV filename'
    option :end,       aliases: ['-E'], type: :string, desc: 'Endtime in ISO format'
    option :partition, aliases: ['-p'], type: :string, desc: 'Filter by partition'
    option :start,     aliases: ['-S'], type: :string, desc: 'Starttime in ISO format'
    option :state,     aliases: ['-s'], type: :string, desc: 'States as comma seperated list'

    # Changed type to boolean so Dry::CLI accepts standalone -u
    option :user,      aliases: ['-u'], type: :boolean,
                       desc: 'Filter by user (defaults to current user if no username specified)'

    def call(**opts)
        inputs = clean_inputs(**opts)
        output = Parser.new.fetch(inputs)
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
      # Not called at all
      return 'none' unless user_flag

      # Check if an explicit username string was provided right after -u or --user in ARGV
      user_index = ARGV.index { |arg| ['--user', '-u'].include?(arg) }
      next_arg = user_index ? ARGV[user_index + 1] : nil

      # If a username value was passed (and isn't another option flag like -p)
      if next_arg && !next_arg.start_with?('-')
        next_arg
      else
        # Fall back to current user resolution when standalone -u / --user is passed
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

Dry::CLI.new(Commands).call if $PROGRAM_NAME == __FILE__
