module Neighborly::Mangopay
  class Customer
    def initialize(user, request_params)
      @user = user
      @request_params = request_params
    end

    def fetch
      if !@user.mangopay_contributor.nil?
        @mangopay_contributor = ::RecursiveOpenStruct.new(@user.mangopay_contributor.attributes)
      else
        if !@user.mangopay_organization_contributor.nil?
          @mangopay_contributor = ::RecursiveOpenStruct.new(@user.mangopay_organization_contributor.attributes)
        else
          @mangopay_contributor = create!
          @mangopay_contributor = ::RecursiveOpenStruct.new(@mangopay_contributor.attributes)
        end
      end
    end

    def update!
      if @user.mangopay_contributor.nil?
        create!
      else
        if @user.profile_type == "personal"
          begin
            @mangopay_contributor = ::MangoPay::NaturalUser.update(
             @user.mangopay_contributor.key,
             Email:              @user.email,
             FirstName:          @user.firstname,
             LastName:           @user.lastname,
             Birthday:           @user.birthday_to_timestamp,
             Nationality:        @user.nationality,
             CountryOfResidence: @user.residence_country,
            )
            puts "==================================================="
            puts "=====MANGOPAY NATURAL USER HAS BEEN UPDATED ======="
            puts "============== #{@mangopay_contributor} ==========="
            puts "==================================================="
            puts "==================================================="
          rescue MangoPay::ResponseError => ex
            puts "==================================================="
            puts "=========MANGOPAY UPDATE NATURAL USER HAS FAILED==="
            puts "============== SEE RESCUE FOR MORE INFO ==========="
            puts "==================================================="
            puts "==================================================="
            puts ex.details
          end
        elsif @user.profile_type == "organization"
          begin
            @mangopay_contributor = ::MangoPay::LegalUser.update(
              @user.mangopay_contributor_by_type.key,
              Name:                                   @user.organization.name,
              Email:                                  @user.email,
              LegalPersonType:                        'ORGANIZATION',
              LegalRepresentativeFirstName:           @user.firstname,
              LegalRepresentativeLastName:            @user.lastname,
              LegalRepresentativeBirthday:            @user.birthday_to_timestamp,
              LegalRepresentativeNationality:         @user.nationality,
              LegalRepresentativeCountryOfResidence:  @user.residence_country,
              LegalRepresentativeAdress:              @user.address
            )
          rescue MangoPay::ResponseError => ex
            puts "==================================================="
            puts "=========MANGOPAY LEGAL USER CREATION HAS FAILED==="
            puts "============== SEE RESCUE FOR MORE INFO ==========="
            puts "==================================================="
            puts "==================================================="
            puts ex.details
          end
        end
      end
    end

    def mangopay_user_url_type(mango_key)
      if @user.profile_type == "organization"
        ::MangoPay::LegalUser.url(mango_key)
      else
        ::MangoPay::NaturalUser.url(mango_key)
      end
    end

    private

    def create!
      if @user.profile_type == "personal"
        begin

            @mangopay_contributor = ::MangoPay::NaturalUser.create(
              Email:              @user.email,
              FirstName:          @user.firstname,
              LastName:           @user.lastname,
              Birthday:           @user.birthday_to_timestamp,
              Nationality:        @user.nationality,
              CountryOfResidence: @user.residence_country,
            )
          @user.create_mangopay_contributor(key: @mangopay_contributor["Id"], href: mangopay_user_url_type(@mangopay_contributor["Id"]))
          puts "==================================================="
          puts "================MANGOPAY USER HAS BEEN CREATED ====================="
          puts "===============#{@mangopay_contributor}====================="
          puts "==================================================="
        rescue MangoPay::ResponseError => ex
          puts "==================================================="
          puts "================MANGOPAY USER CREATION HAS FAILED==="
          puts "===========FOR CLIENT ID => #{ENV['MANGOPAY_CLIENT_ID']} ==========="
          puts "=======AND MANGOPAY API KEY => #{ENV['MANGOPAY_CLIENT_PASSPHRASE']}="
          puts "==================================================="
          puts ex.details
        end
      elsif @user.profile_type == "organization"
        @mangopay_contributor = ::MangoPay::LegalUser.create(
          Name:                                   @user.organization.name,
          Email:                                  @user.email,
          LegalPersonType:                        'ORGANIZATION',
          LegalRepresentativeFirstName:           @user.firstname,
          LegalRepresentativeLastName:            @user.lastname,
          LegalRepresentativeBirthday:            @user.birthday_to_timestamp,
          LegalRepresentativeNationality:         @user.nationality,
          LegalRepresentativeCountryOfResidence:  @user.residence_country,
          LegalRepresentativeAdress:              @user.address
        )
        @user.create_mangopay_organization_contributor(key: @mangopay_contributor.key, href: mangopay_user_url_type(@mangopay_contributor.key))
      else
        raise 'The user has no profile_type, contact the administrator please.'
      end
    end

    def user_params
      @request_params.permit(payment: [user: %i(
                                             name
                                             birthday
                                             nationality
                                             residence_country
                                             address_street
                                             address_city
                                             address_state
                                             address_zip_code
                                           )])[:payment][:user]
    end
  end
end
