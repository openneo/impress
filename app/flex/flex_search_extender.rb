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
      records_by_class_and_id_str = {}
      # returns a structure like {Comment=>[{"_id"=>"123", ...}, {...}], BlogPost=>[...]}
      h = collection.group_by { |d| d.mapped_class(should_raise=true) }
      h.each do |klass, docs|
        record_ids = docs.map(&:_id)
        scope = options[:scopes][klass.name] || klass.scoped
        records = scope.find(record_ids)
        records.each do |record|
          records_by_class_and_id_str[record.class] ||= {}
          records_by_class_and_id_str[record.class][record.id.to_s] = record
        end
      end

      # Reorder records to preserve order from search results
      records = collection.map do |d|
        records_by_class_and_id_str[d.mapped_class][d._id]
      end
      records.extend Flex::Result::Collection
      records.setup(self['hits']['total'], variables)
      records
    end
  end

end
