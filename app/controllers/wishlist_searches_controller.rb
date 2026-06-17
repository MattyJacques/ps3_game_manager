class WishlistSearchesController < ApplicationController
  def index
    @results = GameTdb::Catalog.new.search(params[:q])

    render partial: "wishlist_searches/results", locals: { results: @results }
  end
end
