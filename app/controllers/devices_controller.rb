class DevicesController < ApplicationController
    
    def device_params
        params.require(:device).permit(:name, :device_type, :listing_id)
    end
    
    def new
        @listing = Listing.find(params[:listing_id])
    end
    
    def create
        @listing = Listing.find(params[:listing_id])
        begin
            @device = Device.create!(device_params.merge(:listing_id => @listing.id))
        rescue ActiveRecord::RecordInvalid
            flash[:deny] = "Name and type is required for device."
            redirect_to listing_path(@listing.id)
            return
        end
            
        
        
        endpoints_uri = 'https://graph.api.smartthings.com/api/smartapps/endpoints'
        token = session[:access_token]
    
        url = URI.parse(endpoints_uri)
        req = Net::HTTP::Get.new(url.request_uri)

        # we set a HTTP header of "Authorization: Bearer <API Token>"
        req['Authorization'] = 'Bearer ' + token
    
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = (url.scheme == "https")

        response = http.request(req)
        json = JSON.parse(response.body)
        uri = json[0]['uri']
        newUrl = uri + "/addDevice"
       
        addUrl = URI.parse(newUrl)
        
        addReq = Net::HTTP::Post.new(addUrl.request_uri)
        addReq.set_form_data('id' => @device.id, 'name' => @device.name, 'type' => @device.device_type)
        #we set a HTTP header of "Authorization: Bearer <API Token>"
        addReq['Authorization'] = 'Bearer ' + token
        addHttp = Net::HTTP.new(addUrl.host, addUrl.port)
        addHttp.use_ssl = true
        
        
        response = addHttp.request(addReq)
        case response.body
        when "Device Added Successfully"
            flash[:success] = "Device #{@device.name} created successfully!"
        else
            flash[:deny] = "Error Creating Device"
            @device.destroy
        end
        redirect_to listing_path(@listing.id)
    end
    
end