# frozen_string_literal: true

require 'csv'
require_relative 'models/job'

module AlcesSacct
  class Parser
    HEADERS = %i[
      JobID User Partition State Submit Start End
      Elapsed Planned AllocCPUs TotalCPU ReqMem MaxRSS ExitCode
    ].freeze

    def fetch(flag)
      raw_user = flag[2]
      user = get_user_flag(raw_user)
      partition = get_partition_flag(flag[3])
      states = get_states(flag[4])

      fields = %w[
        JobID User Partition State Submit Start End
        Elapsed Planned AllocCPUs TotalCPU ReqMem MaxRSS ExitCode
      ].join(',')

      cmd = "sacct #{user} -S #{flag[0]} -E #{flag[1]} #{partition} #{states} -P -n -o #{fields}"

      puts cmd
      parse_jobs(`#{cmd}`, raw_user)
    end

    private

    def parse_jobs(output, target_user)
      jobs = {}
      parse_csv_rows(output) do |row_data, raw_id|
        process_job_row(jobs, raw_id, row_data)
      end

      job_list = jobs.values

      # Filter strictly for unknown user records if -U flag was set
      if target_user == 'unknown_only'
        job_list.select { |j| j.user == 'unknown user' }
      else
        job_list
      end
    end

    def parse_csv_rows(output)
      CSV.parse(output.to_s, col_sep: '|') do |row|
        next if row.compact.empty?

        row_data = HEADERS.zip(row).to_h
        raw_id = row_data[:JobID].to_s.strip
        yield(row_data, raw_id) unless raw_id.empty?
      end
    end

    def process_job_row(jobs, raw_id, row_data)
      if raw_id.include?('.')
        parent_id = raw_id.split('.').first
        jobs[parent_id]&.merge_step!(row_data)
      else
        attributes = row_data.transform_keys { |k| Job::HEADER_MAP[k] }
        jobs[raw_id] = Job.new(attributes)
      end
    end

    def get_user_flag(user)
      return '-a' if user == 'none' || user == 'unknown_only'

      "-u #{user}"
    end

    def get_partition_flag(partition)
      return '' if partition == 'all'

      "-r #{partition}"
    end

    def get_states(state)
      return '' if state == 'all'

      "-s #{state}"
    end
  end
end