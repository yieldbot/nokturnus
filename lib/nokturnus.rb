require 'nokturnus/version'

# Load the defaults
#
module Nokturnus
  class << self
      attr_writer :ui
        end

  class << self
      attr_reader :ui
        end
                end
