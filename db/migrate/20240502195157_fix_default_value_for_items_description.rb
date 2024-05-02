class FixDefaultValueForItemsDescription < ActiveRecord::Migration[7.1]
  def change
    # Idk why, but this column's default value is specified in our schema as
    # an empty string, but setting up the dev environment on my macOS machine
    # is saying on latest MariaDB that this isn't allowed.
    change_column_default :items, :description, from: "", to: nil
  end
end
