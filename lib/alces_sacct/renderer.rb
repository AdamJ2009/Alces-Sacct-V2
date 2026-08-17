# frozen_string_literal: true

require 'csv'
require 'tty-table'

module AlcesSacct
  # --- Renderer Class ---
  class Renderer
    METRICS_HEADERS = [
      'Jobs', 'Mean CPU', 'Mean Mem', 'Med CPU',
      'Med Mem', 'Queue Med', 'Queue P95', 'Outcomes', 'Exit Summary'
    ].freeze

    class << self
      def render_single_user_and_partition(ctx)
        row = format_row(ctx[:reporter].metrics)
        return puts 'No jobs found for specified user and partition.' unless row

        user = ctx[:jobs].first&.user
        partition = ctx[:jobs].first&.partition

        headers = %w[User Partition] + METRICS_HEADERS
        title = "Summary for User (#{user}) on Partition (#{partition})"

        render_and_export(headers, [[user, partition, *row]], title, csv_filename: ctx[:csv_name])
      end

      def render_single_user(ctx, show_overall = false)
        headers = ['Partition'] + METRICS_HEADERS
        rows = build_grouped_rows(ctx[:jobs], &:partition)

        if show_overall
          overall_row = format_row(ctx[:reporter].metrics)
          rows << ['overall', *overall_row] if overall_row
        end

        title = "Partition Summary for User (#{ctx[:jobs].first&.user})"
        render_and_export(headers, rows, title, csv_filename: ctx[:csv_name])
      end

      def render_single_partition(ctx, show_overall = false)
        headers = ['User'] + METRICS_HEADERS
        rows = build_grouped_rows(ctx[:jobs], &:user)

        if show_overall
          overall_row = format_row(ctx[:reporter].metrics)
          rows << ['overall', *overall_row] if overall_row
        end

        title = "User Summary for Partition (#{ctx[:jobs].first&.partition})"
        render_and_export(headers, rows, title, csv_filename: ctx[:csv_name])
      end

      def render_unified_summary(ctx, show_overall = false)
        headers = %w[User Partition] + METRICS_HEADERS
        rows = []

        append_overall_rows(rows, ctx[:reporter], ctx[:jobs]) if show_overall
        append_user_rows(rows, ctx[:jobs])

        render_and_export(headers, rows, 'Unified Workload Summary', csv_filename: ctx[:csv_name])
      end

      def render_and_export(headers, rows, title, csv_filename: nil)
        puts "\n#{title}"
        table = TTY::Table.new(headers, rows)
        puts table.render(:unicode, multiline: true) { |r| r.border.separator = :each_row }

        return unless csv_filename && !csv_filename.to_s.strip.empty?

        export_csv(headers, rows, csv_filename)
      end

      def csv_check!(filename)
        return nil if filename.nil?

        unless filename =~ /\.csv$/i
          puts "Error: Invalid CSV filename '#{filename}'. Must end with .csv"
          exit 1
        end

        filename
      end

      private

      def format_row(metrics)
        return nil unless metrics

        [
          metrics[:count], metrics[:mean_cpu], metrics[:mean_mem],
          metrics[:med_cpu], metrics[:med_mem], metrics[:queue_med],
          metrics[:queue_p95], metrics[:outcomes_str], metrics[:exit_str]
        ]
      end

      def append_overall_rows(rows, reporter, jobs)
        overall = format_row(reporter.metrics)
        rows << ['overall', 'overall', *overall] if overall

        jobs.group_by(&:partition).each do |part_name, part_jobs|
          row = format_row(SacctReporter.new(part_jobs).metrics)
          rows << ['overall', part_name, *row] if row
        end
      end

      def append_user_rows(rows, jobs)
        jobs.group_by(&:user).each do |user_name, user_jobs|
          u_row = format_row(SacctReporter.new(user_jobs).metrics)
          rows << [user_name, 'overall', *u_row] if u_row

          user_jobs.group_by(&:partition).each do |part_name, up_jobs|
            up_row = format_row(SacctReporter.new(up_jobs).metrics)
            rows << [user_name, part_name, *up_row] if up_row
          end
        end
      end

      def build_grouped_rows(jobs, &group_block)
        jobs.group_by(&group_block).filter_map do |group_name, job_list|
          m = SacctReporter.new(job_list).metrics
          next unless m

          [group_name, m[:count], m[:mean_cpu], m[:mean_mem], m[:med_cpu], m[:med_mem], m[:queue_med], m[:queue_p95],
           m[:outcomes_str], m[:exit_str]]
        end
      end

      def export_csv(headers, rows, csv_filename)
        CSV.open(csv_filename, 'w') do |csv|
          csv << headers
          rows.each { |row| csv << row }
        end
        puts "\nReport exported successfully to: #{csv_filename}"
      end
    end
  end
end
