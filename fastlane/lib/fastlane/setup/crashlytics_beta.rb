module Fastlane
  class CrashlyticsBeta
    def initialize(beta_info, ui)
      @beta_info = beta_info
      @ui = ui
    end

    def run
      setup = Setup.new

      @ui.message 'This command will generate a fastlane configuration for distributing your app with Beta by Crashlytics'
      @ui.message 'so that you can get your testers new builds with a single command!'

      @ui.message ''

      if setup.is_android?
        UI.user_error!('Sorry, Beta by Crashlytics configuration is currently only available for iOS projects!')
      elsif !setup.is_ios?
        UI.user_error!('Please run Beta by Crashlytics configuration from your iOS project folder.')
      end

      return unless @ui.confirm('Ready to get started?')

      @ui.message "\nAttempting to detect your project settings in this directory...".cyan
      config = {}
      FastlaneCore::Project.detect_projects(config)
      project = FastlaneCore::Project.new(config, xcodebuild_list_silent: true, xcodebuild_suppress_stderr: true)
      scheme = project.schemes.first

      target_name = project.default_build_settings(key: 'TARGETNAME')
      project_file_path = project.is_workspace ? project.path.gsub('xcworkspace', 'xcodeproj') : project.path

      project_parser = CrashlyticsProjectParser.new(target_name, project_file_path)

      info_collector = CrashlyticsBetaInfoCollector.new(project_parser,
                                                        CrashlyticsBetaUserEmailFetcher.new,
                                                        @ui)
      info_collector.collect_info_into(@beta_info)

      if FastlaneFolder.setup?
        @ui.message ""
        @ui.header('Copy and paste the following lane into your Fastfile to use Crashlytics Beta!')
        @ui.message ""
        puts lane_template(scheme).cyan
        @ui.message ""
      else
        fastfile = fastfile_template(scheme)
        FileUtils.mkdir_p('fastlane')
        File.write('fastlane/Fastfile', fastfile)
        @ui.success('A Fastfile has been generated for you at ./fastlane/Fastfile 🚀')
      end
      @ui.header('Next Steps')
      @ui.success('Run the following command to build and upload to Beta by Crashlytics. 🎯')
      @ui.message("\n    fastlane beta")
    end

    def lane_template(scheme)
      discovered_crashlytics_path = Fastlane::Helper::CrashlyticsHelper.discover_default_crashlytics_path

      unless expanded_paths_equal?(@beta_info.crashlytics_path, discovered_crashlytics_path)
        crashlytics_path_arg = "\n         crashlytics_path: '#{@beta_info.crashlytics_path}',"
      end

# rubocop:disable Style/IndentationConsistency
%{  #
  # Learn more here: https://github.com/fastlane/setups/blob/master/samples-ios/distribute-beta-build.md 🚀
  #
  lane :beta do
    # set 'export_method' to 'ad-hoc' if your Crashlytics Beta distribution uses ad-hoc provisioning
    gym(scheme: '#{scheme}', export_method: 'development')

    crashlytics(api_token: '#{@beta_info.api_key}',
             build_secret: '#{@beta_info.build_secret}',#{crashlytics_path_arg}
                   emails: ['#{@beta_info.emails.join("', '")}'], # You can list more emails here
                 # groups: ['group_alias_1', 'group_alias_2'], # You can define groups on the web and reference them here
                    notes: 'Distributed with fastlane 🚀',
            notifications: true) # Should this distribution notify your testers via email?

    # You can notify your team in chat that a beta build has been uploaded
    # slack(
    #   slack_url: "https://hooks.slack.com/services/YOUR/TEAM/INFO"
    #   channel: "beta-releases",
    #   message: "Successfully uploaded a beta release - see it at https://fabric.io/_/beta"
    # )
  end}
      # rubocop:enable Style/IndentationConsistency
    end

    def expanded_paths_equal?(path1, path2)
      return nil if path1.nil? || path2.nil?

      File.expand_path(path1) == File.expand_path(path2)
    end

    def fastfile_template(scheme)
      <<-eos
fastlane_version "#{Fastlane::VERSION}"

default_platform :ios

platform :ios do
#{lane_template(scheme)}
end
eos
    end
  end
end
