#Static functions

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

class SacctReporter
    attr_reader :job
    
    def initialize(job)
        @job = job
    end

    def metrics
        count = @job.size.to_f
        cpu_effs   = @job.map { |j| j[:cpueff] || 0.0 }.sort
        mem_effs   = @job.map { |j| j[:memeff] || 0.0 }.sort
        queuetimes = @job.map { |j| j[:queuetime] || 0.0 }.sort

    end
end
