class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # When the given attribute's value is nil, return the given block's value
  # instead. This is useful for fields where there's a sensible derived value
  # to use as the default for display purposes, but it's distinctly *not* the
  # true value, and should be recognizable as such.
  #
  # This also creates methods `real_<attr>`, `real_<attr>=`, and `real_<attr>?`,
  # to work with the actual attribute when necessary.
  #
  # It also creates `fallback_<attr>`, to find what the fallback value *would*
  # be if the attribute's value were nil.
  def self.fallback_for(attribute_name, &block)
    define_method attribute_name do
      read_attribute(attribute_name) || instance_eval(&block)
    end

    define_method "real_#{attribute_name}" do
      read_attribute(attribute_name)
    end

    define_method "real_#{attribute_name}?" do
      read_attribute(attribute_name).present?
    end

    define_method "real_#{attribute_name}=" do |new_value|
      write_attribute(attribute_name, new_value)
    end

    define_method "fallback_#{attribute_name}" do
      instance_eval(&block)
    end
  end
end