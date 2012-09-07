# coding: UTF-8

class Api::Json::LayersController < Api::ApplicationController
  ssl_required :index, :show, :create, :update, :destroy

  before_filter :load_parent

  def index
    @layers = @parent.layers
    render_jsonp({ :total_entries => @layers.size,
                   :layers => @layers.map(&:public_values)
                })
  end

  def show
    @layer = Layer[params[:id]]

    respond_to do |format|
      format.tilejson do 
       render :text => "#{params[:callback]}( #{@layer.to_tilejson} )"
      end
      format.json do 
        render_jsonp(@layer.public_values)
      end
    end
  end

  def create
    @layer = Layer.new(params.slice(:kind, :options, :infowindow))

    if @layer.save
      @parent.add_layer(@layer.id)
      render_jsonp(@layer.public_values)
    else
      CartoDB::Logger.info "Error on layers#create", @layer.errors.full_messages
      render_jsonp( { :description => @layer.errors.full_messages,
                      :stack => @layer.errors.full_messages
                    }, 400)
    end
  end

  def update
    @layer = Layer[params[:id]]

    if @layer.update(params.slice(:options, :kind, :infowindow))
      render_jsonp(@layer.public_values)
    else
      CartoDB::Logger.info "Error on layers#update", @layer.errors.full_messages
      render_jsonp({ :description => @layer.errors.full_messages, 
        :stack => @layer.errors.full_messages}, 400)
    end
  end

  def destroy
    Layer[params[:id]].destroy
    head :ok
  end


  protected
  
  def load_parent
    if params[:user_id]
      @parent = current_user
    elsif params[:map_id]
      @parent = Map.filter(:user_id => current_user.id, :id => params[:map_id]).first
    end
    raise RecordNotFound if @parent.nil?
  end
end
