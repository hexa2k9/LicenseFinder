require 'xmlsimple'
require_relative 'maven_dependency_finder'

module LicenseFinder
  class Maven < PackageManager
    def initialize(options = {})
      super
      @ignored_groups = options[:ignored_groups]
      @include_groups = options[:maven_include_groups]
      @maven_options = options[:maven_options]
    end

    def current_packages
      command = "#{package_management_command} org.codehaus.mojo:license-maven-plugin:download-licenses"
      command += " -Dlicense.excludedScopes=#{@ignored_groups.to_a.join(',')}" if @ignored_groups && !@ignored_groups.empty?
      command += " #{@maven_options}" unless @maven_options.nil?
      output, success = Dir.chdir(project_path) { capture(command) }
      raise "Command '#{command}' failed to execute: #{output}" unless success

      dependencies = MavenDependencyFinder.new(project_path).dependencies
      packages = dependencies.flat_map do |xml|
        options = {
          'GroupTags' => { 'licenses' => 'license', 'dependencies' => 'dependency' },
          'ForceArray' => %w[license dependency]
        }
        contents = XmlSimple.xml_in(xml, options)['dependencies']
        contents.map do |dep|
          MavenPackage.new(dep, logger: logger, include_groups: @include_groups)
        end
      end
      packages.uniq
    end

    def package_management_command
      wrapper = if Platform.windows?
                  'mvnw.cmd'
                else
                  './mvnw'
                end
      maven = 'mvn'

      File.exist?(File.join(project_path, wrapper)) ? wrapper : maven
    end

    private

    def possible_package_paths
      [project_path.join('pom.xml')]
    end
  end
end
