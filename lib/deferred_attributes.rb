module DeferredAttributes
  def attr_deferred(name, &block)
    instance_variable_name = "@#{name}"
    define_method name do
      value = instance_variable_get(instance_variable_name)
      return value if value
      instance_variable_set(instance_variable_name, self.instance_eval(&block))
    end
  end
end
