class NeopetsPagesController < ApplicationController
  include ActionView::Helpers::TextHelper

  before_filter :authenticate_user!, :build_neopets_page

  rescue_from ClosetPage::ParseError, :with => :on_parse_error

  def create
    if @page_params && @page_params[:source]
      @neopets_page.index = @page_params[:index]
      @neopets_page.source = @page_params[:source]

      saved_counts = @neopets_page.save_hangers!

      any_created = saved_counts[:created] > 0
      any_updated = saved_counts[:updated] > 0
      if any_created || any_updated
        message = "Page #{@neopets_page.index} saved! We "
        message << "added " + pluralize(saved_counts[:created], 'item') + " to the items you own" if any_created
        message << " and " if any_created && any_updated
        message << "updated the count on " + pluralize(saved_counts[:updated], 'item') if any_updated
        message << ". "
      elsif @neopets_page.hangers.size > 1
        message = "Success! We checked that page, and we already had all this data recorded. "
      else
        message = "Success! We checked that page, and there were no wearables to add. "
      end

      unless @neopets_page.unknown_item_names.empty?
        message << "We also found " +
          pluralize(@neopets_page.unknown_item_names.size, 'item') +
          " we didn't recognize: " +
          @neopets_page.unknown_item_names.to_sentence +
          ". Please put each item on your pet and type its name in on the " +
          "home page so we can have a record of it. Thanks! "
      end

      if @neopets_page.last?
        message << "That was the last page of your Neopets #{@neopets_page.name}."
        destination = user_closet_hangers_path(current_user)
      else
        message << "Now the frame should contain page #{@neopets_page.index + 1}. Paste that source code over, too."
        destination = {:action => :new, :index => (@neopets_page.index + 1)}
      end

      flash[:success] = message
      redirect_to destination
    else
      redirect_to :action => :new
    end
  end

  def new
    @neopets_page.index ||= 1
  end

  protected

  TYPES = {
    'closet' => ClosetPage,
    'sdb' => SafetyDepositPage
  }
  def build_neopets_page
    type_class = TYPES[params[:type]]

    @neopets_page = type_class.new(current_user)
    @neopets_page.index = params[:index]
    @page_params = params[type_class.model_name.singular]
  end

  def on_parse_error(e)
    Rails.logger.info "Neopets page parse error: #{e.message}"
    flash[:alert] = "We had trouble reading your source code. Is it a valid " +
      "HTML document? Make sure you pasted the computery-looking result of " +
      "clicking View Frame Source, and not the pretty page itself. "
    render :action => :new
  end
end

