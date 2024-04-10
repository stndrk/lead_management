# frozen_string_literal: true

class OnboardController < ApplicationController
  def onboard
    @customer_lead = CustomerLead.new
    @state_codes = state_codes.map {|name| name.to_s.titleize }.compact
  end

  def create
    @customer_lead = CustomerLead.find_or_initialize_by(mobile: customer_lead_params[:mobile])

    dob = Date.parse(customer_lead_params[:dob])
    age = (Time.zone.now - dob.to_time) / 1.year.seconds

    # @photo_url = upload_image_to_s3(params[:selfie], "selfie")
    # @shop_photo_url = upload_image_to_s3(params[:shop_photo], "shop_photo")

    if age < 21 || age > 55
      @customer_lead.update(customer_lead_params)
      fetch_equifax_report
      render json: {message: "You are not eligible because age must be between 21 and 55 years.", id: @customer_lead.id}, status: :unprocessable_entity
    elsif @customer_lead.update(customer_lead_params)
      fetch_equifax_report
      render json: {message: "Your data has been saved successfully. Our team will contact you to meet your requirements soon.", id: @customer_lead.id}
    else
      render json: {message: @customer_lead.errors.full_messages}
    end
  rescue StandardError => e
    Rails.logger.error("Failed to save data; error #{e.message}")
    render json: {message: "Failed to save data; error #{e.message}"}, status: :unprocessable_entity
  end

  def fetch_equifax_report
    return true
    serv = FetchEquifaxReportService.new(equifax_payload)
    resp = serv.result if serv.fetch

    @is_bureau_approved = if resp && (resp["credit_score"].to_i >= 650 || resp["credit_score"].to_i <= 6)
                            if resp["no_of_active_accounts"].to_i <= 5 && resp["total_balance_amount"].to_i <= 500_000
                              true
                            else
                              false
                            end
                          else
                            false
                          end

    @customer_lead.update(bureau_score: resp["credit_score"], equifax_response: resp, is_bureau_approved: @is_bureau_approved)
    Faircent.new.register_lead(@customer_lead.mobile) unless @is_bureau_approved
  end

  def upload_image_to_s3
    cust = CustomerLead.find(params[:id])
    base64data = params[:base64data]
    image_key = params[:imageKey]

    if base64data && image_key
      s3_url = upload(base64data, image_key, cust.mobile)
      if s3_url
        key = image_key == "selfie" ? :photo_url : :shop_photo_url
        cust.update(key => s3_url)
        render json: {message: "Images uploaded successfully"}, status: :ok
      else
        render json: {error: "Failed to upload images"}, status: :unprocessable_entity
      end
    else
      render json: {error: "Missing required parameters"}, status: :unprocessable_entity
    end
  end

  private

  def upload(base64data, image_key, mobile)
    s3 = Aws::S3::Resource.new
    decoded_image = Base64.decode64(base64data)

    image = MiniMagick::Image.read(decoded_image)
    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    filename = "#{image_key}_#{timestamp}_#{mobile}.#{ext_for(image.mime_type)}"
    object_key = "arth_happy_tide/#{filename}"
    bucket_name = "arthimpact-athos-#{CURRENT_ENV}-eabe0xpfef"

    obj = s3.bucket(bucket_name).object(object_key)
    return obj.public_url if obj.exists?

    obj.put(body: image.to_blob, acl: "public-read", content_type: image.mime_type)

    s3_presigner = Aws::S3::Presigner.new
    presigned_url = s3_presigner.presigned_url(:get_object, bucket: bucket_name, key: object_key, expires_in: 3600)

    presigned_url
  rescue StandardError => e
    Rails.logger.error("#{e.message} failed to upload and generate presigned URL")
    nil
  end

  def ext_for(mime_type)
    mime_type.split("/").last
  end

  def state_codes
    [
      "andhrapradesh", "arunachalpradesh", "assam", "bihar", "chattisgarh", "delhi", "goa", "gujarat", "haryana", "himachalpradesh", "jammuandkashmir",
      "jammu&kashmir", "jharkhand", "karnataka", "kerala", "lakshadweepislands", "lakshadweep", "madhyapradesh", "maharashtra", "manipur", "meghalaya",
      "mizoram", "nagaland", "odisha", "orissa", "pondicherry", "punjab", "rajasthan", "sikkim", "tamilnadu", "telangana", "tripura", "uttarpradesh",
      "uttarakhand", "westbengal", "andamanandnicobarislands", "andaman&nicobar", "chandigarh", "dadraandnagarhaveli", "damananddiu", "daman&diu",
      "otherterritory", "Uttaranchal"
    ]
  end

  def equifax_payload
    {
      name:       customer_lead_params[:name],
      first_name: customer_lead_params[:first_name],
      last_name:  customer_lead_params[:last_name],
      address:    customer_lead_params[:home_address],
      pincode:    customer_lead_params[:home_pincode],
      state:      customer_lead_params[:home_state],
      birthdate:  customer_lead_params[:dob],
      mobile:     customer_lead_params[:mobile],
      pan:        customer_lead_params[:pan_number]
    }
  end

  def customer_lead_params
    params.require(:customer_lead).permit(:first_name, :last_name, :dob, :pan_number, :mobile, :email, :guardian_name, :gender, :alternate_mobile_number, :education_level, :home_city, :home_state, :business_city,
                                          :insurance, :is_owned_customer_shop_type, :business_type, :guardian_occupation, :shop_road_type, :shop_photo_url, :other_occupation, :monthly_income, :business_state,
                                          :type_of_loan, :other_details, :home_address, :home_pincode, :business_address, :business_pincode).merge(latitude: params[:latitude], longitude: params[:longitude],
    accuracy: params[:accuracy], occupation_category: params[:occupation_category], relation_with_guardian: params[:relation_with_guardian])
  end
end
