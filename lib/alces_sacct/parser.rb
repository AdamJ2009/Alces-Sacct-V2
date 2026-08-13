require 'csv'
require_relative 'models/job'

class Parser

    HEADERS = %i[
    JobID User Partition State Submit Start End
    Elapsed Planned AllocCPUs TotalCPU ReqMem MaxRSS ExitCode
  ].freeze

    def fetch(flag)
        user = get_user_flag(flag[2])
        partition = get_partition_flag(flag[3])
        states = get_states(flag[4])
        cmd = "sacct " + user + " -S #{flag[0]} -E #{flag[1]} " + partition + " " + states + " -P -n \
  -o JobID,User,Partition,State,Submit,Start,End,Elapsed,Planned,AllocCPUs,TotalCPU,ReqMem,MaxRSS,ExitCode"
        puts cmd
        command_value = `#{cmd}`
        parse_jobs(command_value)
    end
    private

    def parse_jobs(output)
    jobs_by_id = {}

    CSV.parse(output, col_sep: '|') do |row|
      next if row.compact.empty?

      # Create a hash pairing HEADERS with the row values
      row_data = HEADERS.zip(row).to_h

      raw_id = row_data[:JobID].to_s.strip
      next if raw_id.empty?

      # Check if this row represents a step (e.g. 12345.batch or 12345.0) vs a main job ID
      if raw_id.include?('.')
        parent_id = raw_id.split('.').first
        jobs_by_id[parent_id]&.merge_step!(row_data)
      else
        attributes = row_data.transform_keys { |k| Job::HEADER_MAP[k] }
        jobs_by_id[raw_id] = Job.new(attributes)
      end
    end

    jobs_by_id.values
  end

    def get_user_flag(user)
        return '-a' if user == "none"
        return "-u #{user}" 
    end

    def get_partition_flag(partition)
        return "" if partition == "all"
        return "-r #{partition}"
    end

    def get_states(state)
        return "" if state == "all"
        return "-r #{state}"
    end

end