class ClosetPagesController < ApplicationController
  include ActionView::Helpers::TextHelper

  before_filter :authenticate_user!, :build_closet_page

  rescue_from ClosetPage::ParseError, :with => :on_parse_error

  def create
    if params[:closet_page] && params[:closet_page][:source]
      @closet_page.index = params[:closet_page][:index]
      @closet_page.source = params[:closet_page][:source]

      saved_counts = @closet_page.save_hangers!

      any_created = saved_counts[:created] > 0
      any_updated = saved_counts[:updated] > 0
      if any_created || any_updated
        message = "Page #{@closet_page.index} saved! We "
        message << "added " + pluralize(saved_counts[:created], 'item') + " to your closet" if any_created
        message << " and " if any_created && any_updated
        message << "updated the count on " + pluralize(saved_counts[:updated], 'item') if any_updated
        message << ". "
      else
        message = "Success! We checked that page, and we already had all this data recorded. "
      end

      unless @closet_page.unknown_item_names.empty?
        message << "We also found " +
          pluralize(@closet_page.unknown_item_names.size, 'item') +
          " we didn't recognize: " +
          @closet_page.unknown_item_names.to_sentence +
          ". Please put each item on your pet and type its name in on the " +
          "home page so we can have a record of it. Thanks! "
      end

      if @closet_page.last?
        message << "That was the last page of your Neopets closet."
        destination = user_closet_hangers_path(current_user)
      else
        message << "Now the frame should contain page #{@closet_page.index + 1}. Paste that source code over, too."
        destination = {:action => :new, :index => (@closet_page.index + 1)}
      end

      flash[:success] = message
      redirect_to destination
    else
      redirect_to :action => :new
    end
  end

  def new
    @closet_page.index ||= 1
  end

  protected

  def build_closet_page
    @closet_page = ClosetPage.new(current_user)
    @closet_page.index = params[:index]
  end

  def on_parse_error
    flash[:alert] = "We had trouble reading your source code. Is it a valid HTML document? Make sure you pasted the computery-looking result of clicking View Frame Source, and not the pretty page itself."
    render :action => :new
  end
end

