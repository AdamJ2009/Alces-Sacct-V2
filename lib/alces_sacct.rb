# frozen_string_literal: true

require_relative 'alces_sacct/version'
require_relative 'alces_sacct/models/job'
require_relative 'alces_sacct/parser'
require_relative 'alces_sacct/reporter'
require_relative 'alces_sacct/cli'

# Primary namespace for the AlcesSacct gem.
# Handles parsing, aggregating, and displaying Slurm sacct accounting data.
module AlcesSacct
  class Error < StandardError; end
end
