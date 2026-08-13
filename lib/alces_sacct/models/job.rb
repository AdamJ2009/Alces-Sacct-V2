class Job
  attr_accessor :job_id, :user, :partition, :state, :submit, :start, :end_time,
                :elapsed, :planned, :alloc_cpus, :total_cpu, :req_mem, :max_rss, :exit_code

  HEADER_MAP = {
    JobID:     :job_id,
    User:      :user,
    Partition: :partition,
    State:     :state,
    Submit:    :submit,
    Start:     :start,
    End:       :end_time,
    Elapsed:   :elapsed,
    Planned:   :planned,
    AllocCPUs: :alloc_cpus,
    TotalCPU:  :total_cpu,
    ReqMem:    :req_mem,
    MaxRSS:    :max_rss,
    ExitCode:  :exit_code
  }.freeze

  def initialize(attributes = {})
    attributes.each do |key, value|
      setter = "#{key}="
      send(setter, value) if respond_to?(setter)
    end
  end

  def merge_step!(step_attributes)
    self.max_rss = step_attributes[:MaxRSS] unless step_attributes[:MaxRSS].to_s.strip.empty?

    HEADER_MAP.each do |header, attr_name|
      current_val = send(attr_name)
      step_val = step_attributes[header]

      if (current_val.nil? || current_val.to_s.empty?) && !step_val.to_s.empty?
        send("#{attr_name}=", step_val)
      end
    end
  end

  def to_h
    HEADER_MAP.values.each_with_object({}) do |attr, hash|
      hash[attr] = send(attr)
    end
  end
end