require 'spec_helper'

describe Neighborly::Mangopay::Refund do
  let(:payable_resource) do
    double(
      class:               double(model_name: double(human: 'Resource')),
      id:                  '1',
      payment_id:          '1234567890',
      payment_service_fee: 1.3,
      payment_service_fee_paid_by_user: true,
      refund!:             nil,
      value:               100.0
    )
  end
  let(:debit) { double('Debit', refund: nil) }
  subject { described_class.new(payable_resource) }

  describe 'debit' do
    it 'gets the debit object through Mangopay API' do
      Mangopay::Debit.stub(:find).
        with('/debits/1234567890').
        and_return(debit)
      expect(subject.debit).to eql(debit)
    end
  end

  describe 'completion' do
    before { subject.stub(:debit).and_return(debit) }
    let(:operational_fee) { described_class::FIXED_OPERATIONAL_FEE }

    context 'without passing amount parameter' do
      context 'when contributor paid payment service fees' do
        before do
          payable_resource.stub(:payment_service_fee_paid_by_user).and_return(true)
        end

        it 'refunds them using cents unit plus refundable fee' do
          expect(debit).to receive(:refund).with(hash_including(amount: 10100))
          subject.complete!(:match_automatic)
        end

        it 'refunds an integer amount' do
          debit.stub(:refund) do |args|
            expect(args[:amount]).to be_an(Integer)
          end
          subject.complete!(:match_automatic)
        end
      end

      context 'when contributor didn\'t paid payment service fees' do
        before do
          payable_resource.stub(:payment_service_fee_paid_by_user).and_return(false)
        end

        it 'refund contributed value using cents unit' do
          expect(debit).to receive(:refund).with(hash_including(amount: 9970))
          subject.complete!(:match_automatic)
        end

        it 'refunds an integer amount' do
          debit.stub(:refund) do |args|
            expect(args[:amount]).to be_an(Integer)
          end
          subject.complete!(:match_automatic)
        end
      end
    end

    context 'passing amount parameter' do
      it 'refunds in the value given plus refundable fees' do
        expect(debit).to receive(:refund).with(hash_including(amount: 4225))
        subject.complete!(:match_automatic, 42)
      end
    end

    context 'with non zero amount' do
      it 'performs a refund through Mangopay API for the given payable_resource' do
        expect(debit).to receive(:refund)
        subject.complete!(:match_automatic, 12)
      end

      context 'with successful refund through Mangopay' do
        it 'sets the payable_resource as refunded' do
          expect(payable_resource).to receive(:refund!)
          subject.complete!(:match_automatic)
        end
      end

      context 'with unsuccessful refund through Mangopay' do
        before do
          debit.stub(:refund).and_raise { Mangopay::Error }
        end

        it 'doesn\'t update state of the payable_resource to refunded' do
          expect(payable_resource).to_not receive(:refund!)
          subject.complete!(:match_automatic) rescue nil
        end
      end
    end

    context 'with zero amount' do
      it 'sets the payable_resource as refunded' do
        expect(payable_resource).to receive(:refund!)
        subject.complete!(:match_automatic, 0)
      end

      it 'doesn\'t perform request to Mangopay API' do
        expect(debit).to_not receive(:refund)
        subject.complete!(:match_automatic, 0)
      end
    end
  end

  describe 'refundable fees' do
    before do
      stub_const("#{described_class}::FIXED_OPERATIONAL_FEE", 0.3)
      payable_resource.stub(:value).and_return(100.0)
      payable_resource.stub(:payment_service_fee).and_return(1.3)
    end

    context 'when user paid fees' do
      before do
        payable_resource.stub(:payment_service_fee_paid_by_user).and_return(true)
      end

      it 'returns percentage fee on full refund' do
        expect(
          subject.refundable_fees(payable_resource.value)
        ).to eql(1.0)
      end

      it 'returns percentage fee proportionally to percentage fee part of the payment' do
        expect(
          subject.refundable_fees(60.0)
        ).to eql(0.48)
      end
    end

    context 'when user didn\'t paid fees' do
      before do
        payable_resource.stub(:payment_service_fee_paid_by_user).and_return(false)
      end

      it 'returns negative fixed fee on full refund' do
        expect(
          subject.refundable_fees(payable_resource.value)
        ).to eql(-described_class::FIXED_OPERATIONAL_FEE)
      end

      it 'returns negative fixed fee on partial refund' do
        expect(
          subject.refundable_fees(60.0)
        ).to eql(-described_class::FIXED_OPERATIONAL_FEE)
      end
    end
  end
end
