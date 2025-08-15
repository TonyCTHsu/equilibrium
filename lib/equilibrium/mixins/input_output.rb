# frozen_string_literal: true

require "json"
require_relative "../summary_formatter"

module Equilibrium
  module Mixins
    # Module for input/output operations - reading files, parsing JSON, formatting output
    module InputOutput
      def read_input_data(file_path = nil, usage_message = "No input provided")
        input = file_path ? File.read(file_path) : $stdin.read
        input = input.strip

        raise usage_message if input.empty?
        input
      end

      def format_output(data, format, summary_type = nil)
        case format
        when "json"
          puts JSON.pretty_generate(data)
        when "summary"
          if summary_type
            formatter = SummaryFormatter.new
            case summary_type
            when "expected", "actual"
              formatter.print_tags_summary(data, summary_type)
            when "analysis"
              formatter.print_analysis_summary(data)
            end
          else
            puts JSON.pretty_generate(data)
          end
        else
          puts JSON.pretty_generate(data)
        end
      end
    end
  end
end
