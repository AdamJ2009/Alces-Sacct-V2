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
end