require 'spec_helper'

describe Neighborly::Mangopay::Customer do
  let(:user)    { double('User').as_null_object }
  let(:params)  { ActionController::Parameters.new( {
                  payment: {
                     user: { name:              'Name',
                             address_street:    '',
                             address_city:      '',
                             address_state:     '',
                             address_zip_code:  '' } }
  } ) }

  let(:mangopay_customer) do
    double('::Mangopay::Customer', href: '/qwertyuiop').as_null_object
  end

  before do
    ::Mangopay::Customer.stub(:find).and_return(mangopay_customer)
    ::Mangopay::Customer.stub(:new).and_return(mangopay_customer)
  end

  subject { Neighborly::Mangopay::Customer.new(user, params) }

  describe '#fetch' do
    context 'when user already has a mangopay_contributor associated' do
      before do
        contributor = double('Neighborly::Mangopay::Contributor',
                             href: '/qwertyuiop')
        user.stub(:mangopay_contributor).
                  and_return(contributor)
      end

      it 'skips creation of new costumer' do
        expect(mangopay_customer).to_not receive(:save)
        subject.fetch
      end
    end

    context "when user don't has mangopay_contributor associated" do
      before do
        user.stub(:mangopay_contributor)
      end

      it 'saves a new costumer' do
        expect(mangopay_customer).to receive(:save)
        subject.fetch
      end

      it 'defines user_id in the meta data of the costumer' do
        customer_attrs = hash_including(meta: hash_including(:user_id))
        ::Mangopay::Customer.should_receive(:new).with(customer_attrs)
        subject.fetch
      end
    end

    describe '#update!' do
      describe 'update of user attributes' do
        it "reflects attributes in user's resource " do
          expect(user).to receive(:update!)
          subject.update!
        end
      end

      describe 'update Mangopay customer' do
        it "mangopay_customer should receive save on update" do
          expect(mangopay_customer).to receive(:save)
          subject.update!
        end
      end
    end
  end
end
