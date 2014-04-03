class WardrobeTip < ActiveRecord::Base
  translates :body

  scope :by_index, order('`index` ASC')
end
