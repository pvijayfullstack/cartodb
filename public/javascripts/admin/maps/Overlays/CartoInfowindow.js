

	function CartoInfowindow(latlng, map) {
	  this.latlng_ = latlng;
		this.marker_;
		this.map_ = map;
		this.columns_;
	
	  this.offsetHorizontal_ = -107;
	  this.width_ = 214;
	
	  this.setMap(map);
	}
	

	CartoInfowindow.prototype = new google.maps.OverlayView();


	CartoInfowindow.prototype.draw = function() {
					
	  var me = this;
		var num = 0;
		

	  var div = this.div_;
	  if (!div) {
	    div = this.div_ = document.createElement('div');
	    div.setAttribute('class','marker_infowindow');
	
			$(div).append('<a href="#close" class="close">x</a>'+
			              '<div class="outer_top">'+
			                '<div class="top">'+
			                '</div>'+
			              '</div>'+
			              '<div class="bottom">'+
											'<label>cartodb_id:1</label>'+
											'<a class="edit_point" href="#edit">edit</a>'+
											'<a class="delete_point" href="#delete">delete</a>'+
		                '</div>');
		

			$(div).find('a.close').click(function(ev){
				stopPropagation(ev);
				carto_map.unbindMapESC();
				me.hide();
			});

			$(div).find('a.delete_point').click(function(ev){
				stopPropagation(ev);
				me.hide();
				carto_map.delete_window_.open(me.latlng_,me.marker_);
			});
			
			$(div).find('a.edit_point').click(function(ev){
				stopPropagation(ev);
				me.hide();
				carto_map.createFakeGeometry(me.marker_);
			});
      
      google.maps.event.addDomListener(div,'click',function(ev){stopMapPropagation(ev);});
      google.maps.event.addDomListener(div,'dblclick',function(ev){stopMapPropagation(ev);});
      google.maps.event.addDomListener(div,'mousedown',function(ev){stopMapPropagation(ev);});
      google.maps.event.addDomListener(div,'mouseup',function(ev){stopMapPropagation(ev);});
      google.maps.event.addDomListener(div,'mousemove',function(ev){stopMapPropagation(ev);});
			
	    var panes = this.getPanes();
	    panes.floatPane.appendChild(div);
	
			$(div).css({opacity:0});
	  }
	
	  var pixPosition = this.getProjection().fromLatLngToDivPixel(this.latlng_);
	  if (pixPosition) {
		  div.style.width = this.width_ + 'px';
		  div.style.left = (pixPosition.x - 49) + 'px';
		  var actual_height = - $(div).height();
		  div.style.top = (pixPosition.y + actual_height + 5) + 'px';
	  }
	};
	
	
	CartoInfowindow.prototype.setPosition = function() {
	  
	  if (this.div_) { 
  	  var div = this.div_;
  	  var pixPosition = this.getProjection().fromLatLngToDivPixel(this.latlng_);
  	  if (pixPosition) {
  		  div.style.width = this.width_ + 'px';
  		  div.style.left = (pixPosition.x - 49) + 'px';
  		  var actual_height = - $(div).height();
  		  div.style.top = (pixPosition.y + actual_height + 5) + 'px';
  	  }
  	  this.show();
    }
	}
	
	
	CartoInfowindow.prototype.open = function(feature){
	  var me = this;
	  this.marker_ = feature;
	  
	  $.ajax({
      method: "GET",
      url:global_api_url + 'tables/'+table_name+'/records/'+feature,
      headers: {"cartodbclient": true},
      success:function(data){
        positionateInfowindow(me,data,carto_map.infowindow_vars_);
      },
      error:function(e){}
    });
    
    
    function positionateInfowindow(me,info,variables) {
      if (me.div_) {
        // Set ESC binding
        carto_map.bindMapESC();
        
  	    var div = me.div_;
  	    // Get latlng position
  	    me.latlng_ = transformGeoJSON(info.the_geom).center;
  	    
  	    var query_mode = $('body').attr('query_mode') === 'true';

  	    $(div).find('div.top').html('');

  	    _.each(info,function(value,label){
  	      if ((label!='cartodb_id' && variables[label]) || (label!='cartodb_id' && query_mode)) {
    				$(div).find('div.top').append('<label>'+label+'</label><p class="'+((info[label]!=null)?'':'empty')+'">'+value+'</p>');
  	      }
  	    });
  	    
  	    // If app in query mode?
  	    if (query_mode) {
  	      $(div).find('a.delete_point').hide();
    			$(div).find('a.edit_point').hide();
  	    } else {
  	      $(div).find('a.delete_point').show();
    			$(div).find('a.edit_point').show();
  	    }

  			$(div).find('div.bottom').find('label').html('cartodb_id: <strong>'+info.cartodb_id+'</strong>');
  	    me.moveMaptoOpen();
  	    me.setPosition();			
  	  }
    }
	}	
	

	CartoInfowindow.prototype.hide = function() {
	  if (this.div_) {
	    var div = this.div_;
	    $(div).stop().animate({
	      top: '+=' + 10 + 'px',
	      opacity: 0
	    }, 100, 'swing', function(ev){
				div.style.visibility = "hidden";
			});
	  }
	}


	CartoInfowindow.prototype.show = function() {
	  if (this.div_) {
	    var div = this.div_;
			$(div).css({opacity:0});
			div.style.visibility = "visible";

	    $(div).stop().animate({
	      top: '-=' + 10 + 'px',
	      opacity: 1
	    }, 250, 'swing');
			
		}
	}


	CartoInfowindow.prototype.isVisible = function(marker_id) {
	  if (this.div_) {
	    var div = this.div_;
			if ($(div).css('visibility')=='visible' && this.marker_!=null && this.marker_.data.cartodb_id==marker_id) {
				return true;
			} else {
				return false;
			}
		} else {
			return false;
		}
	}
	
	
	CartoInfowindow.prototype.moveMaptoOpen = function() {
		var left = 0;
		var top = 0;
		var div = this.div_;
	  var pixPosition = this.getProjection().fromLatLngToContainerPixel(this.latlng_);

		if ((pixPosition.x + this.offsetHorizontal_) < 0) {
			left = (pixPosition.x + this.offsetHorizontal_ - 20);
		}
		
		if ((pixPosition.x + 180) >= ($('div#map').width())) {
			left = (pixPosition.x + 180 - $('div#map').width());
		}
		
		if ((pixPosition.y - $(div).height()) < 0) {
			top = (pixPosition.y - $(div).height() - 30);
		}
				
		this.map_.panBy(left,top);
	}
