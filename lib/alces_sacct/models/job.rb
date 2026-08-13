# frozen_string_literal: true

module AlcesSacct
  # --- Job Class ---
  class Job
    attr_accessor :job_id, :user, :partition, :state, :submit, :start, :end_time,
                  :elapsed, :planned, :alloc_cpus, :total_cpu, :req_mem, :max_rss, :exit_code

    HEADER_MAP = {
      JobID: :job_id,
      User: :user,
      Partition: :partition,
      State: :state,
      Submit: :submit,
      Start: :start,
      End: :end_time,
      Elapsed: :elapsed,
      Planned: :planned,
      AllocCPUs: :alloc_cpus,
      TotalCPU: :total_cpu,
      ReqMem: :req_mem,
      MaxRSS: :max_rss,
      ExitCode: :exit_code
    }.freeze

    def initialize(attributes = {})
      attributes.each do |key, value|
        setter = "#{key}="
        send(setter, value) if respond_to?(setter)
      end
    end

    # Merge attributes from a child step record (e.g. .batch) into this main job
    def merge_step!(step_attributes)
      # Priority update: MaxRSS usually resides in the step record
      update_max_rss(step_attributes[:MaxRSS])

      # Backfill missing parent attributes using non-empty step attributes
      HEADER_MAP.each do |header, attr_name|
        backfill_attribute(attr_name, step_attributes[header])
      end
    end

    # --- Efficiency Calculations ---

    # CPU Efficiency %: Total CPU time / (Allocated CPUs * Elapsed Walltime) * 100
    def cpu_efficiency
      cpus = alloc_cpus.to_i
      walltime_sec = time_to_seconds(elapsed)

      return 0.0 if cpus.zero? || walltime_sec.zero?

      cpu_sec = time_to_seconds(total_cpu)
      ((cpu_sec / (cpus * walltime_sec.to_f)) * 100.0).round(4)
    end

    # Memory Efficiency %: MaxRSS / ReqMem * 100
    def mem_efficiency
      req_mb = parse_memory_to_mb(req_mem)
      max_mb = parse_memory_to_mb(max_rss)

      return 0.0 if req_mb.zero?

      ((max_mb / req_mb.to_f) * 100.0).round(4)
    end

    # Utility to hash job data including calculated fields
    def to_h
      HEADER_MAP.values.each_with_object({}) do |attr, hash|
        hash[attr] = send(attr)
      end.merge(
        cpu_eff: cpu_efficiency,
        mem_eff: mem_efficiency
      )
    end

    private

    def time_str_to_seconds(time_str)
      return 0.0 if time_str.to_s.strip.empty?

      match = time_str.to_s.strip.match(/(?:(\d+)-)?(?:(\d+):)?(\d+):(\d+(?:\.\d+)?)/)
      return 0.0 unless match

      d, h, m, s = match.captures.map(&:to_f)

      (d * 86_400) + (h * 3600) + (m * 60) + s
    end

    def update_max_rss(rss)
      self.max_rss = rss if present?(rss)
    end

    def backfill_attribute(attr_name, step_val)
      return unless present?(step_val) && blank?(send(attr_name))

      send("#{attr_name}=", step_val)
    end

    def present?(val)
      !val.to_s.strip.empty?
    end

    def blank?(val)
      val.nil? || val.to_s.strip.empty?
    end

    # Converts standard Slurm memory representations (e.g. "8022M", "1820K", "2G") to float Megabytes
    def parse_memory_to_mb(mem_str)
      return 0.0 if mem_str.nil? || mem_str.to_s.strip.empty?

      num = mem_str.to_f
      unit = mem_str.to_s.gsub(/[^a-zA-Z]/, '').upcase

      case unit
      when 'K', 'KB' then num / 1024.0
      when 'M', 'MB', '' then num
      when 'G', 'GB' then num * 1024.0
      when 'T', 'TB' then num * 1024.0 * 1024.0
      else num
      end
    end
  end
end
