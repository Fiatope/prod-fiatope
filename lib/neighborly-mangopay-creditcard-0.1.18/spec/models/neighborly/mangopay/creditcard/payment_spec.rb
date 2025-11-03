require 'spec_helper'

describe Neighborly::Mangopay::Creditcard::Payment do
  shared_examples_for 'payable' do
    let(:customer)     { double('::Mangopay::Customer') }
    let(:debit)        { double('::Mangopay::Debit').as_null_object }
    let(:attributes)   { { use_card: 'my-new-card' } }
    let(:project_owner_customer) do
      double('::Mangopay::Customer', uri: 'project-owner-uri')
    end

    let(:card) do
      double('::Mangopay::Card',
             id:  '443',
             href: '/cards/443').as_null_object
    end

    subject do
      described_class.new('mangopay-creditcard',
                          customer,
                          resource,
                          attributes)
    end

    before do
      ::Mangopay::Card.stub(:fetch).and_return(card)
      ::Mangopay::Customer.stub(:find).and_return(project_owner_customer)
      resource.stub_chain(:project, :user, :mangopay_contributor).and_return(
        double('MangopayContributor', uri: 'project-owner-uri'))

      described_class.any_instance.stub(:meta).and_return({})
      resource.stub(:value).and_return(1234)
    end

    describe 'amount in cents' do
      context 'when customer is paying fees' do
        let(:attributes) { { pay_fee: '1', use_card: 'my-new-card' } }

        it 'returns gross amount from TransactionAdditionalFeeCalculator' do
          Neighborly::Mangopay::Creditcard::TransactionAdditionalFeeCalculator.
            any_instance.stub(:gross_amount).and_return(15)
          expect(subject.amount_in_cents).to eql(1500)
        end
      end

      context 'when customer is not paying fees' do
        let(:attributes) { { pay_fee: '0', use_card: 'my-new-card' } }

        it 'returns gross amount from TransactionInclusiveFeeCalculator' do
          Neighborly::Mangopay::Creditcard::TransactionInclusiveFeeCalculator.
            any_instance.stub(:gross_amount).and_return(10)
          expect(subject.amount_in_cents).to eql(1000)
        end
      end
    end

    describe 'checkout' do
      shared_examples 'updates resource object' do
        let(:attributes) { { pay_fee: '1', use_card: 'my-new-card' } }

        it 'debits customer on selected funding instrument' do
          expect_any_instance_of(
            Neighborly::Mangopay::OrderProxy
          ).to receive(:debit_from).with(hash_including(source: card)).
            and_return(debit)
          subject.checkout!
        end

        it 'defines given engine\'s name as payment method of the resource' do
          resource.should_receive(:update_attributes).
                       with(hash_including(payment_method: 'mangopay-creditcard'))
          subject.checkout!
        end

        it 'saves paid fees on resource object' do
          calculator = double('FeeCalculator', fees: 0.42).as_null_object
          subject.stub(:fee_calculator).and_return(calculator)
          resource.should_receive(:update_attributes).
                       with(hash_including(payment_service_fee: 0.42))
          subject.checkout!
        end

        it 'saves who paid the fees' do
          calculator = double('FeeCalculator', fees: 0.42).as_null_object
          subject.stub(:fee_calculator).and_return(calculator)
          resource.should_receive(:update_attributes).
                       with(hash_including(payment_service_fee_paid_by_user: '1'))
          subject.checkout!
        end
      end

      context 'when customer is paying fees' do
        let(:attributes) { { pay_fee: '1', use_card: 'my-new-card' } }

        it 'debits customer with amount in cents' do
          subject.stub(:amount_in_cents).and_return(1000)
          expect_any_instance_of(
            Neighborly::Mangopay::OrderProxy
          ).to receive(:debit_from).with(hash_including(amount: 1000)).
            and_return(debit)
          subject.checkout!
        end
      end

      context 'with successful debit' do
        before do
          allow_any_instance_of(
            Neighborly::Mangopay::OrderProxy
          ).to receive(:debit_from).and_return(debit)
        end

        include_examples 'updates resource object'

        it 'confirms the resource' do
          expect(resource).to receive(:confirm!)
          subject.checkout!
        end

        it 'defines id as payment id of the resource' do
          debit.stub(:id).and_return('i-am-an-id!')
          resource.should_receive(:update_attributes).
                       with(hash_including(payment_id: 'i-am-an-id!'))
          subject.checkout!
        end

        it 'defines appears_on_statement_as on debit' do
          ::Configuration.stub(:[]).with(:mangopay_appears_on_statement_as).
            and_return('Neighbor.ly')

          expect_any_instance_of(
            Neighborly::Mangopay::OrderProxy
          ).to receive(:debit_from).
            with(hash_including(appears_on_statement_as: 'Neighbor.ly')).
            and_return(debit)
          subject.checkout!
        end

        it 'defines description on debit' do
          resource.stub_chain(:project, :name).and_return('Awesome Project')
          expect_any_instance_of(
            Neighborly::Mangopay::OrderProxy
          ).to receive(:debit_from).
            with(hash_including(description: debit_description)).
            and_return(debit)
          subject.checkout!
        end

        it 'defines meta on debit' do
          described_class.any_instance.stub(:meta).and_return({ payment_service_fee: 5.0 })
          expect_any_instance_of(
            Neighborly::Mangopay::OrderProxy
          ).to receive(:debit_from).
            with(hash_including(meta: { payment_service_fee: 5.0 })).
            and_return(debit)
          subject.checkout!
        end
      end

      context 'when raising Mangopay::PaymentRequired exception' do
        before do
          allow_any_instance_of(
            Neighborly::Mangopay::OrderProxy
          ).to receive(:debit_from).
            and_raise(Mangopay::PaymentRequired.new({}))
        end

        include_examples 'updates resource object'

        it 'cancels the resource' do
          expect(resource).to receive(:cancel!)
          subject.checkout!
        end
      end
    end

    describe 'successful state' do
      before do
        allow_any_instance_of(
          Neighborly::Mangopay::OrderProxy
        ).to receive(:debit_from).and_return(debit)
      end

      context 'after checkout' do
        before { subject.checkout! }

        it 'is successfull when the debit has \'succeeded\' status' do
          debit.stub(:status).and_return('succeeded')
          expect(subject).to be_successful
        end

        it 'is successfull when the debit has \'pending\' status' do
          debit.stub(:status).and_return('pending')
          expect(subject).to be_successful
        end

        it 'is not successfull when the debit has others statuses' do
          debit.stub(:status).and_return('failed')
          expect(subject).to_not be_successful
        end
      end

      context 'before checkout' do
        it 'is not successfull' do
          expect(subject).to_not be_successful
        end
      end
    end
  end

  context 'when resource is Contribution' do
    let(:resource)          { Contribution.new }
    let(:debit_description) { 'Contribution to Awesome Project' }

    it_should_behave_like 'payable'
  end

  context 'when resource is Match' do
    let(:resource)          { Match.new }
    let(:debit_description) { 'Match for Awesome Project' }

    it_should_behave_like 'payable'
  end
end
