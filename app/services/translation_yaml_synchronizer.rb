# frozen_string_literal: true

require 'tempfile'
require 'yaml'

class TranslationYamlSynchronizer
  def self.enabled?
    ActiveModel::Type::Boolean.new.cast(ENV['TRANSLATION_RUNTIME_YAML_SYNC'])
  end

  def self.call(language)
    return false unless enabled?

    path = Rails.root.join('config', 'locales', "#{language.code}.yml")
    document = path.file? ? YAML.safe_load_file(path, aliases: false) : {}
    document = {} unless document.is_a?(Hash)
    document[language.locale] ||= {}

    language.translates.find_each do |translation|
      assign_missing(document[language.locale], translation.key, translation.value)
    end

    write_atomically(path, document)
    true
  end

  def self.assign_missing(root, dotted_key, value)
    parts = dotted_key.split('.')
    leaf = parts.pop
    node = parts.reduce(root) { |current, part| current[part] ||= {} }
    node[leaf] = value unless node.key?(leaf)
  end

  def self.write_atomically(path, document)
    path.dirname.mkpath

    Tempfile.create(["#{path.basename}.", '.tmp'], path.dirname) do |file|
      file.write(document.to_yaml)
      file.flush
      file.fsync
      File.chmod(path.file? ? path.stat.mode : 0o644, file.path)
      File.rename(file.path, path)
    end
  end

  private_class_method :assign_missing, :write_atomically
end
