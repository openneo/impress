Flex.class_eval do
  class << self
    include ::NewRelic::Agent::MethodTracer
    
    verbs = %w(bulk count create_index delete_by_query delete_index
               delete_mapping exist get get_mapping get_settings indices_exists
               multi_get post_index post_store put_index put_mapping put_store
               remove stats store)
    
    verbs.each do |method|
      add_method_tracer(method)
    end
  end
end
