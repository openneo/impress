class Contribution < ActiveRecord::Base
  POINT_VALUES = {
    'Item' => 3,
    'SwfAsset' => 2,
    'PetType' => 15,
    'PetState' => 10
  }

  belongs_to :contributed, :polymorphic => true
  belongs_to :user
  
  scope :recent, -> { order('id DESC') }
  
  cattr_reader :per_page
  @@per_page = 30
  
  def point_value
    POINT_VALUES[contributed_type] ||
      raise("unexpected contributed type #{contributed_type.inspect} for " +
            "contributed #{contributed.inspect}")
  end
  
  CONTRIBUTED_RELATIONSHIPS = {
    'SwfAsset' => 'Item',
    'PetState' => 'PetType'
  }
  CONTRIBUTED_CHILDREN = CONTRIBUTED_RELATIONSHIPS.keys
  CONTRIBUTED_TYPES = CONTRIBUTED_CHILDREN + CONTRIBUTED_RELATIONSHIPS.values
  def self.preload_contributeds_and_parents(contributions, options={})
    options[:scopes] ||= {}
    
    # Initialize the groups we'll be using for quick access
    contributions_by_type = {}
    contributed_by_type = {}
    contributed_by_type_and_id = {}
    needed_ids_by_type = {}
    CONTRIBUTED_TYPES.each do |type|
      contributions_by_type[type] = []
      contributed_by_type[type] = []
      contributed_by_type_and_id[type] = {}
      needed_ids_by_type[type] = []
    end
    
    # Go through the contributions to sort them for future contributed
    # assignment, and so we can know what immediate contributed items we'll
    # need to look up
    contributions.each do |contribution|
      type = contribution.contributed_type
      contributions_by_type[type] << contribution
      needed_ids_by_type[type] << contribution.contributed_id
    end
    
    # Load contributed objects without parents, prepare them for easy access
    # for future assignment to contributions and looking up parents
    CONTRIBUTED_CHILDREN.each do |type|
      scope = options[:scopes][type] || type.constantize.all
      scope.find(needed_ids_by_type[type]).each do |contributed|
        contributed_by_type[type] << contributed
        contributed_by_type_and_id[type][contributed.id] = contributed
      end
    end
    
    # Load both parents of the children we just got, and immediately
    # contributed objects of that class. all_by_ids_or_children properly
    # assigns parents to children, as well
    CONTRIBUTED_RELATIONSHIPS.each do |child_type, type|
      scope = options[:scopes][type] || type.constantize.all
      ids = needed_ids_by_type[type]
      children = contributed_by_type[child_type]
      scope.all_by_ids_or_children(ids, children).each do |contributed|
        contributed_by_type_and_id[type][contributed.id] = contributed
      end
    end
    
    # Assign contributed objects to contributions
    contributions.each do |contribution|
      type = contribution.contributed_type
      id = contribution.contributed_id
      contribution.contributed = contributed_by_type_and_id[type][id]
    end
  end
end
