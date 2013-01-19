# see the detailed Extenders documentation at https://github.com/ddnexus/flex/wiki/Extenders

module FlexSearchExtender

  # set this method to restrict this extender to certain types of results
  # see the other Flex extenders for reference (https://github.com/ddnexus/flex/tree/master/lib/flex/result)
  def self.should_extend?(response)
    true
  end
  
  def scoped_loaded_collection(options)
    options[:scopes] ||= {}
    @loaded_collection ||= begin
      records  = []
      # returns a structure like {Comment=>[{"_id"=>"123", ...}, {...}], BlogPost=>[...]}
      h = Flex::Utils.group_array_by(collection) do |d|
        d.mapped_class(should_raise=true)
      end
      h.each do |klass, docs|
        scope = options[:scopes][klass.name] || klass.scoped
        records |= scope.find(docs.map(&:_id))
      end
      class_ids = collection.map { |d| [d.mapped_class.to_s,  d._id] }
        # Reorder records to preserve order from search results
        records = class_ids.map do |class_str, id|
          records.detect do |record|
          record.class.to_s == class_str && record.id.to_s == id.to_s
        end
      end
      records.extend Flex::Result::Collection
      records.setup(self['hits']['total'], variables)
      records
    end
  end

end
