# frozen_string_literal: true

# --- Helper Functions ---

def calc_median
  lambda do |arr|
    len = arr.length
    return 0.0 if len.zero?

    (arr[(len - 1) / 2] + arr[len / 2]) / 2.0
  end
end

def calc_p95
  lambda do |arr|
    return 0.0 if arr.empty?

    rank = (0.95 * arr.length).ceil - 1
    arr[[rank, 0].max]
  end
end

def format_pct(val)
  "#{val.round(2)}%"
end

def format_sec(val)
  "#{val.round(2)}s"
end

# Converts Slurm time string ("HH:MM:SS" or "MM:SS") to float seconds
def time_str_to_seconds(time_str)
  return 0.0 if time_str.nil? || time_str.to_s.strip.empty?

  parts = time_str.to_s.strip.split(':').map(&:to_f)
  case parts.size
  when 3 then (parts[0] * 3600) + (parts[1] * 60) + parts[2]
  when 2 then (parts[0] * 60) + parts[1]
  else parts[0] || 0.0
  end
end

# --- Reporter Class ---

class SacctReporter
  attr_reader :jobs

  def initialize(jobs)
    @jobs = Array(jobs)
  end

  # Calculates top-level aggregated metrics for the jobs passed in
  def metrics
    return nil if @jobs.empty?

    count, cpus, mems, queues = base_metrics
    outcomes = get_outcomes(count)

    mean_and_med_metrics(count, cpus, mems)
      .merge(queue_metrics(queues))
      .merge(count: @jobs.size, outcomes_str: outcomes[0], exit_str: outcomes[1])
  end

  # Build table rows for grouped job hashes without including the group_name column
  def build_rows(grouped_hash)
    grouped_hash.filter_map do |_group_name, job_list|
      reporter = SacctReporter.new(job_list)
      m = reporter.metrics
      next unless m

      [
        m[:count], m[:mean_cpu], m[:mean_mem], m[:med_cpu],
        m[:med_mem], m[:queue_med], m[:queue_p95], m[:outcomes_str], m[:exit_str]
      ]
    end
  end

  private

  def base_metrics
    count = @jobs.size.to_f

    cpu_effs   = @jobs.map { |j| j.cpu_efficiency || 0.0 }.sort
    mem_effs   = @jobs.map { |j| j.mem_efficiency || 0.0 }.sort
    queuetimes = @jobs.map { |j| time_str_to_seconds(j.planned) }.sort

    [count, cpu_effs, mem_effs, queuetimes]
  end

  def get_outcomes(count)
    [format_outcomes(count), format_exit_summary]
  end

  def format_outcomes(count)
    state_counts = @jobs.group_by(&:state)
    outcomes_pct = state_counts.transform_values do |state_jobs|
        ((state_jobs.size / count) * 100).round(2)
    end

    # Compact inline format: "COMPLETED: 91.79%, FAILED: 8.21%"
    outcomes_pct.map { |k, v| "#{k}: #{v}%" }.join(', ')
    end

    def format_exit_summary
    # Compact inline format: "0:0 (212), 0:9 (12)"
    @jobs.group_by(&:exit_code)
        .transform_values(&:size)
        .map { |code, count| "#{code} (#{count})" }
        .join(', ')
    end

  def mean_and_med_metrics(count, cpus, mems)
    {
      mean_cpu: format_pct(cpus.sum / count),
      mean_mem: format_pct(mems.sum / count),
      med_cpu: format_pct(calc_median.call(cpus)),
      med_mem: format_pct(calc_median.call(mems))
    }
  end

  def queue_metrics(queues)
    {
      queue_med: format_sec(calc_median.call(queues)),
      queue_p95: format_sec(calc_p95.call(queues))
    }
  end
end