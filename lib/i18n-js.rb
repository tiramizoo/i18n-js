# frozen_string_literal: true

require "i18n"
require "json"
require "yaml"
require "glob"
require "fileutils"
require "optparse"

require_relative "i18n-js/schema"
require_relative "i18n-js/version"

module I18nJS
  MissingConfigError = Class.new(StandardError)

  def self.call(config_file: nil, config: nil)
    if !config_file && !config
      raise MissingConfigError,
            "you must set either `config_file` or `config`"
    end

    config = Glob::SymbolizeKeys.call(config || YAML.load_file(config_file))
    Schema.validate!(config)
    exported_files = []

    config[:translations].each do |group|
      exported_files += export_group(group)
    end

    exported_files
  end

  def self.export_group(group)
    filtered_translations = Glob.filter(translations, group[:patterns])
    output_file_path = File.expand_path(group[:file])
    exported_files = []

    if output_file_path.include?(":locale")
      filtered_translations.each_key do |locale|
        locale_file_path = output_file_path.gsub(/:locale/, locale.to_s)
        exported_files << write_file(locale_file_path,
                                     locale => filtered_translations[locale])
      end
    else
      exported_files << write_file(output_file_path, filtered_translations)
    end

    exported_files
  end

  def self.write_file(file_path, translations)
    FileUtils.mkdir_p(File.dirname(file_path))

    contents = ::JSON.pretty_generate(translations)
    digest = Digest::MD5.hexdigest(contents)
    file_path = file_path.gsub(/:digest/, digest)

    File.open(file_path, "w") do |file|
      file << contents
    end

    file_path
  end

  def self.translations
    ::I18n.backend.instance_eval do
      has_been_initialized_before =
        respond_to?(:initialized?, true) && initialized?
      init_translations unless has_been_initialized_before
      translations
    end
  end
end
