# frozen_string_literal: true

class Job
  attr_accessor :job_id, :user, :partition, :state, :submit, :start, :end_time,
                :elapsed, :planned, :alloc_cpus, :total_cpu, :req_mem, :max_rss, :exit_code

  HEADER_MAP = {
    JobID:    :job_id,
    User:     :user,
    Partition: :partition,
    State:    :state,
    Submit:   :submit,
    Start:    :start,
    End:      :end_time,
    Elapsed:  :elapsed,
    Planned:  :planned,
    AllocCPUs: :alloc_cpus,
    TotalCPU: :total_cpu,
    ReqMem:   :req_mem,
    MaxRSS:   :max_rss,
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
    self.max_rss = step_attributes[:MaxRSS] unless step_attributes[:MaxRSS].to_s.strip.empty?

    # Backfill any missing parent attributes using non-empty step attributes
    HEADER_MAP.each do |header, attr_name|
      current_val = send(attr_name)
      step_val = step_attributes[header]

      if (current_val.nil? || current_val.to_s.empty?) && !step_val.to_s.empty?
        send("#{attr_name}=", step_val)
      end
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

  # Converts Slurm time formats ("HH:MM:SS", "MM:SS", or "SS.ms") into total floating-point seconds
  def time_to_seconds(time_str)
    return 0.0 if time_str.nil? || time_str.to_s.strip.empty?

    parts = time_str.to_s.strip.split(':').map(&:to_f)
    case parts.size
    when 3 then (parts[0] * 3600) + (parts[1] * 60) + parts[2] # HH:MM:SS
    when 2 then (parts[0] * 60) + parts[1]                   # MM:SS.ms
    else parts[0] || 0.0
    end
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