#--
# Test Case v1.2 by Solistra
# =============================================================================
# 
# Summary
# -----------------------------------------------------------------------------
#   This script provides a simple unit testing framework for RPG Maker VX Ace
# with very simple expectation-style formatting for test cases. Essentially,
# this script allows you to use test-driven development from within RPG Maker
# VX Ace without depending on an external Ruby installation. This is primarily
# a scripter's tool.
# 
# Usage
# -----------------------------------------------------------------------------
#   There is no succinct way to summarize the usage of this script. However,
# this script is heavily documented with examples if you wish to simply consult
# the supplied documentation. In addition, a usage tutorial is available at
# [SES VXA](http://sesvxace.wordpress.com/2014/04/10/a-case-for-unit-testing/).
# 
#   Note that the usage tutorial for this script makes heavy use of the
# Assertions extension. Ensure that you are using this extension before you
# review the tutorial.
# 
# Extensions
# -----------------------------------------------------------------------------
#   This script only provides the core SES Test Case framework needed to create
# and run unit tests. In addition to the core framework, there are a number of
# extensions which have been written to provide enhanced functionality, all of
# which may be found on GitHub at the following location:
# 
# * [Test Case Extensions]
#   (https://github.com/sesvxace/test-case/tree/master/lib/extensions)
# 
# The Assertions extension, in particular, is highly recommended -- but not
# strictly necessary in order to write functional unit tests.
# 
# License
# -----------------------------------------------------------------------------
#   This script is made available under the terms of the MIT Expat license.
# View [this page](http://sesvxace.wordpress.com/license/) for more detailed
# information.
# 
# Installation
# -----------------------------------------------------------------------------
#   Place this script below Materials, but above Main and any tests. Place this
# script below the SES Core (v2.0 or higher) if you are using it.
# 
#++

# SES
# =============================================================================
# The top-level namespace for all SES scripts.
module SES
  # Test
  # ===========================================================================
  # Defines management and running of defined subclasses of {SES::Test::Case}.
  module Test
    # =========================================================================
    # BEGIN CONFIGURATION
    # =========================================================================
    
    # Whether or not to automatically run all test cases whenever the game is
    # started in test mode.
    AUTO_RUN = true
    
    # The directory used to store external test files. This path is relative to
    # your game's root directory.
    # 
    # **NOTE:** External test files must have a '.rb' extension to be loaded.
    TEST_DIR = 'System/Tests'
    
    # =========================================================================
    # END CONFIGURATION
    # =========================================================================
    
    # Add the configured `TEST_DIR` to the Ruby load path.
    $LOAD_PATH.unshift(File.expand_path(TEST_DIR))
    
    # Returns an array of known test cases.
    # 
    # @return [Array<SES::Test::Case, SES::Test::Spec>] an array of known cases
    def self.cases
      @cases ||= []
    end
    
    # Loads external test cases located in the {SES::Test::TEST_DIR} directory.
    # 
    # @return [Boolean] `true` if test cases were loaded, `false` otherwise
    def self.load_cases
      return false if @loaded
      Dir.glob(TEST_DIR + '/**/*.rb') { |file| load(file) }
      @loaded = true
    end
    
    # Loads external test cases if they have not yet been loaded, then runs a
    # new instance of every known test case. Provides a `Test::Unit`-style
    # summary of the run test cases.
    # 
    # @return [Array] an array of test results
    def self.run(options = {})
      load_cases
      start_time = Time.now
      assertions = []
      cases.each { |test_case| assertions.push(*test_case.new.run(options)) }
      puts("Ran #{assertions.size} tests defined in #{cases.size} cases.")
      puts("Test Summary: #{summarize(assertions)}")
      puts("Elapsed Time: %.2f second(s)\n " % (Time.now - start_time))
      assertions
    end
    
    # Provides a `Test::Unit`-style summary of assertions.
    # 
    # @param assertions [Array<Boolean, nil, Exception>] the assertions to
    #   summarize
    # @return [String] a summary of assertion results
    def self.summarize(assertions)
      assertions.map { |element|
        case element
        when true  ; '.'
        when nil   ; 'S'
        when false ; 'F'
        else       ; 'E'
        end
      }.join
    end
    # Skip
    # =========================================================================
    # Exception raised when a test unit should be skipped.
    class Skip < StandardError
    end
    # DSL
    # =========================================================================
    # A simple DSL for {SES::Test::Spec} instances.
    module DSL
      # Sets the block to call before each spec is run.
      # 
      # @example
      #   before { subject.push(1, 2, 3) }
      # 
      # @return [Proc]
      def before(&block)
        define_method(:setup) { instance_eval(&block) }
      end
      alias_method :before_each, :before
      
      # Sets the block to call after each spec is run.
      # 
      # @example
      #   after { subject.clear }
      # 
      # @return [Proc]
      def after(&block)
        define_method(:teardown) { instance_eval(&block) }
      end
      alias_method :after_each, :after
      
      # Describes a spec for the test case. The passed description is used for
      # display purposes, while the passed block is used as the actual spec to
      # be tested.
      # 
      # @example
      #   it 'should respond to #pop' do
      #     subject.respond_to?(:pop)
      #   end
      # 
      # @param description [String] the description for this spec
      # @return [Proc]
      def it(description = '(undefined)', &block)
        block ||= ->{ skip }
        method_name = ('test_' << description.gsub(/[^\w\?\!]/, '_')).to_sym
        descriptions[method_name] = description
        define_method(method_name, &block)
      end
      alias_method :specify, :it
      
      # Creates a reader method with the passed name which returns the value of
      # the passed block (evaluated in the context of the instance).
      # 
      # @note This method automatically generates an instance variable with the
      #   name of the reader method prepended with an underscore which contains
      #   the appropriate value.
      # 
      # @example
      #   let :array do Array.new end
      #   it 'demonstrates `#let`' do
      #     array == []
      #   end
      # 
      # @param name [Symbol] the name of the reader method
      # @return [Proc]
      def let(name, &block)
        define_method(name) { eval("@_#{name} ||= instance_exec(&block)") }
      end
      
      # Sets the subject for this test case to the return value of the passed
      # block. This is a convenience method which essentially creates a reader
      # method named `#subject` which returns the passed block's return value.
      # 
      # @example
      #   subject { Array.new }
      #   it 'should respond to #pop' do
      #     subject.respond_to?(:pop)
      #   end
      # 
      # @return [Proc]
      def subject(&block)
        let(:subject, &block)
      end
      alias_method :target, :subject
      
      # Sets the displayed name for this test case to the passed name (or the
      # default `#name` of the subject). The block given to this method creates
      # the subject for this test case automatically. The name is set to the
      # name of the subject's class if no name is passed to this method.
      # 
      # @example
      #   describe 'Array' do Array.new end
      #   subject # => []
      # 
      # @param name [String, nil] the name for this test case; set to `nil` to
      #   use the default name
      # @return [String] the name for this test case
      def describe(name = nil, &block)
        subject(&block)
        @name = name.nil? ? subject.class.name : name
      end
      
      # Overwrite of `#name` for this instance. Primarily used to format
      # output.
      # 
      # @return [String]
      def name
        defined?(@name) ? @name : super
      end
      alias_method :to_s, :name
    end
    # Reporter
    # =========================================================================
    # Formats test case information and writes information to a given stream.
    class Reporter
      # The output stream this {Reporter} should write to.
      # @return [Object]
      attr_accessor :stream
      
      # Provides output formatting for individual test units.
      # 
      # @param title [#to_s] the name of the test case
      # @param desc [#to_s] the description of this test unit
      # @param pass [Boolean, nil] `true` if the unit passed, `false` if it
      #   failed for any reason, `nil` if it was skipped
      # @param error [Exception] the error encountered if the test failed due
      #   to a raised exception
      # @return [String] the formatted test unit information
      def self.format_case(title, desc, pass, error = nil)
        pass = case pass
        when true  then ' OK '
        when false then 'FAIL'
        when nil   then 'SKIP' end
        pass = 'ERR!' if error
        "  [#{pass}] #{title} #{desc} #{"\n\t -- #{error.message}" if error}"
      end
      
      # Formats the given symbol (by default) into a descriptive string by
      # removing the 'test_' prefix (if it exists) and replacing underscores
      # with spaces.
      # 
      # @note This method is used by the {Case} class for writing descriptions
      #   for test methods.
      # 
      # @param symbol [#to_s] the descriptive symbol to format
      # @return [String] the formatted description
      def self.format_desc(symbol)
        symbol.to_s.gsub!(/^test_/, '').gsub!('_', ' ')
      end
      
      # Provides output formatting for the footer of a test case. Essentially
      # writes statistics for the test case.
      # 
      # @param a [Array<Boolean, nil, Exception>] an array of assertions to
      #   format; see {Case#wrapper} for more information about how assertions
      #   are coerced into values
      # @return [String] the formatted footer
      # 
      # @see Case#wrapper
      def self.format_footer(a)
        n, p, s, f = a.size, a.count(true), a.count(nil), a.count(false)
                 e = a.select { |element| element.kind_of?(Exception) }.size
        "\n  #{n} tests, #{p} passed, #{s} skipped, #{f} failed, " << \
          "#{e} errors\n "
      end
      
      # Provides output formatting for the header of a test case.
      # 
      # @param title [#to_s] the title for the header
      # @return [String] the formatted header
      def self.format_header(title)
        "Test Case: #{title}\n"
      end
      
      # Instantiate a new {Reporter} with the given stream. Streams may be any
      # object which responds to the `#puts` method (standard output by
      # default).
      # 
      # @param stream [#puts] the stream to write reports to
      # @return [self]
      def initialize(stream = $stdout)
        @stream = stream
      end
      
      # Writes formatted output to this instance's `@stream`.
      # 
      # @note The given `type` is used to call an appropriate `.format_` method
      #   which takes the given `args` and performs output formatting. Consult
      #   the appropriate formatting methods for more information.
      # 
      # @param type [#to_s] the type of report to create; by default, may be
      #   one of `:case`, `:desc`, `:footer`, or `:header`
      # @param args [Array] the arguments to pass to the requested formatter
      # @return [String] the formatted report
      # 
      # @see .format_case
      # @see .format_desc
      # @see .format_footer
      # @see .format_header
      def report(type, *args)
        return nil if !self.class.respond_to?(type = "format_#{type}".to_sym)
        return_value = self.class.send(type, *args)
        @stream.send(:puts, return_value)
        return_value
      end
    end
    # Case
    # =========================================================================
    # Defines a basic test case. All test cases are subclasses of this class.
    class Case
      class << self
        # Whether or not to skip this test suite.
        # @return [Boolean]
        attr_accessor :skip
      end
      
      # Include the subclass of this class in the Test module's `@cases`
      # instance variable unless the subclass is already in it (or the subclass
      # is {Spec}, a specialized subclass of {Case} for specifications).
      # 
      # @param subclass [Class] the class which inherited this class
      # @return [nil]
      def self.inherited(subclass)
        unless Test.cases.include?(subclass) || subclass == SES::Test::Spec
          Test.cases << subclass
        end
        super
      end
      
      # Convenience method for setting the class instance variable `@skip` to a
      # `true` value.
      # 
      # @return [TrueClass]
      def self.skip!
        self.skip = true
      end
      
      # An array of runnable test methods used by this instance's {#run}
      # method.
      # 
      # @return [Array<Symbol>]
      def runnable_methods
        methods.select { |method| method =~ /^test_/ }
      end
      
      # The {SES::Test::Reporter} instance for this test case.
      # 
      # @return [SES::Test::Reporter]
      def reporter
        @reporter ||= Reporter.new
      end
      
      # Provides specific output directions for each runnable test method. This
      # is defined here to allow redefinition of case output in the {Spec}
      # class.
      # 
      # @param string [String] the string to format for output by a {Reporter}
      # @return [String] the formatted report
      def report_case(string, *values)
        reporter.report(:case, name, Reporter.format_desc(string), *values)
      end
      
      # Convenience method allowing individual test methods to be skipped by
      # calling this method rather than raising a {Skip} exception manually.
      # 
      # @raise [SES::Test::Skip]
      def skip
        raise(SES::Test::Skip.new)
      end
      
      # Wraps around test methods to ensure they return expected values. This
      # method facilitates the `#setup` and `#teardown` methods and ensures
      # that tests return `true`, `false`, `nil`, or `Exception` values.
      # 
      # @return [Boolean, nil, Exception] the return value of the test method
      #   coerced into a `true`, `false`, `nil`, or `Exception` value
      def wrapper
        setup if respond_to?(:setup)
        yield ? true : false
      rescue Skip
        nil
      rescue Exception => ex
        ex.class == AssertionError ? false : ex
      ensure
        teardown if respond_to?(:teardown)
      end
      alias_method :wrap, :wrapper
      
      # Runs all runnable test methods for this test case and returns an array
      # containing each method's return value. Runs are sent to the reporter
      # for formatting and output unless the run is designated as silent.
      # 
      # @param options [Hash{Symbol => Boolean}] hash of options; suitable keys
      #   are `:force` and `:silent` with appropriate boolean values
      # @return [Array<Object>] an array of return values from each runnable
      #   test method
      def run(options = {})
        return [] if self.class.skip && !options[:force]
        reporter.report(:header, name) unless options[:silent]
        assertions = []
        runnable_methods.each do |runnable|
          val = assertions.push(wrap { method(runnable).call }).last
          unless options[:silent]
            val = val.kind_of?(Exception) ? [false, assertions.last] : [val] 
            report_case(runnable, *val)
          end
        end
        reporter.report(:footer, assertions) unless options[:silent]
        assertions
      end
      
      # The name for this test case. Defaults to the name of this instance's
      # class. Used primarily for output formatting by the reporter.
      # 
      # @return [String] the name for this test case
      def name
        self.class.name
      end
    end
    # Spec
    # =========================================================================
    # Specialized subclass of {SES::Test::Case} for writing specification-style
    # tests.
    class Spec < Case
      extend DSL
      
      # Hash for containing full descriptions for generated `#test_` methods.
      # 
      # @return [Hash{Symbol => String}]
      def self.descriptions
        @descriptions ||= {}
      end
      
      # Reports case information with full descriptions rather than parsed
      # method names (allows for more natural specifications).
      # 
      # @param method [Symbol] the method to obtain a description for
      # @param values [Array] an array of values to pass to {Reporter#report}
      # @return [String] the formatted report
      def report_case(method, *values)
        reporter.report(:case, name, self.class.descriptions[method], *values)
      end
    end
    
    # Register this script with the SES Core if it exists.
    if SES.const_defined?(:Register)
      # Script metadata.
      Description = Script.new('Test Case', 1.2, :Solistra)
      Register.enter(Description)
    end
  end
end
# DataManager
# =============================================================================
# Manages the database and game objects.
module DataManager
  class << self
    # Aliased to automatically run test cases if {SES::Test::AUTO_RUN} is set
    # to a `true` value. {DataManager}'s default {DataManager.init .init} class
    # method is run first (which allows tests to make use of the standard RGSS3
    # global variables).
    # 
    # @see .init
    alias_method :ses_testcase_dm_init, :init
  end
  
  # Initializes the standard global variables used by RGSS3.
  # 
  # @return [void]
  def self.init(*args, &block)
    ses_testcase_dm_init(*args, &block)
    SES::Test.run if SES::Test::AUTO_RUN && $TEST
  end
end