require 'noktumus/version'

# Load the defaults
#
module Noktumus
  class << self
      attr_writer :ui
        end

  class << self
      attr_reader :ui
        end
                end
