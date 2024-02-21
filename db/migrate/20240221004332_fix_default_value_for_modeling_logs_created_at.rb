class FixDefaultValueForModelingLogsCreatedAt < ActiveRecord::Migration[7.1]
  def change
    # NOTE: This isn't a field used in the Rails app; it's one used in Impress
    # 2020, and when we imported the latest schema into here, the importer
    # didn't correctly capture the default field it uses.
    #
    # So, this is just us fixing the dev environment as declared by `schema.rb`
    # to match how things already are in prod!
    change_column_default :modeling_logs, :created_at,
      from: nil, to: -> { "CURRENT_TIMESTAMP" }
  end
end
