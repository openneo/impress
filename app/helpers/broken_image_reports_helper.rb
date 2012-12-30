module BrokenImageReportsHelper
  def format_converted_at(converted_at)
    translate 'broken_image_reports.new.converted_at_html',
              :converted_at_ago => labeled_time_ago_in_words(converted_at)
  end
  
  def format_reported_at(reported_at)
    translate 'broken_image_reports.new.reported_at_html',
              :reported_at_ago => labeled_time_ago_in_words(reported_at)
  end
end
