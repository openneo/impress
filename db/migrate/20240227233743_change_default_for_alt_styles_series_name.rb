class ChangeDefaultForAltStylesSeriesName < ActiveRecord::Migration[7.1]
  def change
    change_column_null :alt_styles, :series_name, true
    change_column_default :alt_styles, :series_name, from: "<New?>", to: nil
  end
end
