# encoding: UTF-8
# frozen_string_literal: true

describe WalletService::Bitcoind do

  around do |example|
    WebMock.disable_net_connect!
    example.run
    WebMock.allow_net_connect!
  end

  let(:deposit) { create(:deposit_btc) }
  let(:wallet) { Wallet.find_by_gateway('bitcoind') }
  let(:client) { WalletService[wallet] }

  before do
    if respond_to?(:request_body) && respond_to?(:response_body)
      stub_request(:post, 'http://127.0.0.1:18332/').with(body: request_body).to_return(body: response_body)
    end
  end

  describe '#create_address' do
    subject { client.create_address }

    let :request_body do
      { jsonrpc: '1.0', method: 'getnewaddress', params: [] }.to_json
    end

    let :response_body do
      { result: '2N7r9zKXkypzqtXfWkKfs3uZqKbJUhdK6JE' }.to_json
    end

    it { is_expected.to eq(address: '2N7r9zKXkypzqtXfWkKfs3uZqKbJUhdK6JE') }
  end

  let(:currency) { Currency.find_by_id(:btc) }

  let!(:payment_address) do
    create(:btc_payment_address, address: '2N7r9zKXkypzqtXfWkKfs3uZqKbJUhdK6JE')
  end

  let!(:destination_address) do
    create(:btc_destination_address, address: '2MvCSzoFbQsVCTjN2rKWPuHa3THXSp1mHWt')
  end

  describe '#collect_deposit!' do
    subject { client.collect_deposit!(deposit) }
    let(:hash) { 'fd0e7e0d21b000d39716df5a46399cc4087137e2dbdb3de4ff4db907ce58b9df' }
    # # let (:destination_address) { destination_wallet(deposit).address }
    # let (:pa) { deposit.account.payment_address }
    #
    let :request_body do
      { jsonrpc: '1.0', method: 'sendtoaddress',params:[hash] }.to_json
    end
    #
    let :response_body do
      '{ "result":{"status":200,"body":"","headers": {} }'
      # { status: 200, body: "", headers: {} }
    end
    #
    it 'should deduct fee from amount' do
    #   # puts destination_address
    #   puts "============================== #{deposit.currency_id}"
      is_expected.to eq( '{ "result":{"status":200,"body":"","headers": {} }')
    end
    # stub_request(:post, "http://127.0.0.1:18332/").
    #     with(
    #         body: "{\"jsonrpc\":\"1.0\",\"method\":\"sendtoaddress\",\"params\":[\"0x2b9fBC10EbAeEc28a8Fc10069C0BC29E45eBEB9C\",\"3819.0\",\"\",\"\",true]}",
    #         headers: {
    #             'Accept'=>'application/json',
    #             'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
    #             'Content-Type'=>'application/json',
    #             'User-Agent'=>'Faraday v0.14.0'
    #         }).
    #     to_return(status: 200, body: "", headers: {})
    # end



  end

  # describe '#load_deposit!' do
  #   let(:hash) { 'fd0e7e0d21b000d39716df5a46399cc4087137e2dbdb3de4ff4db907ce58b9df' }
  #   subject { client.load_deposit!(hash) }
  #
  #   let :request_body do
  #     { jsonrpc: '1.0',
  #       method:  'gettransaction',
  #       params:  [hash]
  #     }.to_json
  #   end
  #
  #   let :response_body do
  #     '{"result":{"amount":0.00000000,"fee":-0.00000257,"confirmations":4738,"blockhash":"00000000e92125f72f0e132d324d16a7693ddda53d2e8545b701c2baa076dc01","blockindex":608,"blocktime":1523535985,"txid":"fd0e7e0d21b000d39716df5a46399cc4087137e2dbdb3de4ff4db907ce58b9df","walletconflicts":[],"time":1523535100,"timereceived":1523535100,"bip125-replaceable":"no","details":[{"account":"","address":"2NA6umNrb57TCGGN2cj49sSdW5SzpcVaqYB","category":"send","amount":-0.00050000,"label":"","vout":1,"fee":-0.00000257,"abandoned":false},{"account":"","address":"2NA6umNrb57TCGGN2cj49sSdW5SzpcVaqYB","category":"receive","amount":0.00050000,"label":"","vout":1}],"hex": "020000000001024a97da778f9882f65546e62ec9aee3dbbe7c25fa585a147926b1d81e992013270100000017160014800b4788ef66faefdcc6a3e64dc60872a9c757c7feffffffe723c21b0bad8ae854a5043b6b323a3ee05bbb8c26878ab4095bf23bc1d1c43b01000000171600143eecb6c1a17fcdbebdf197b6a07eb7436476469efeffffff0298e20f000000000017a914588efda1527c61b00cda3876439ac6df6c4e0f8b8750c300000000000017a914b8e7996763e653b1fe618577ec7672e6add09de68702483045022100c5eb3113e49b965b7cf516d3cc9e70eba421439d26890fa1bdc319bdfceba6bd02201473e4a29705a74fb741b1b48b519bb69f33bbf987eee6fc8374cde865cd49d5012103e1b3043e86fd175b7cae3b0bc91e005f6aaeecb66949560e4f0310e28da8f9ce02483045022100f49085c0ea0945ad806d2d4dfe7743b15edb6447b069117b3c28b45ab835d7c9022008bda8d2348ce9d9169bdf2e9a3e0434f7b4bf2d30ade14fa04e1f380e1eed03012102e4b431866f1e1e771b452ad1540e1cbbb959889515a76298fe06ba7266c45d1afab81300"},"error":null,"id":null}'
  #   end
  #
  #   it do
  #     is_expected.to eq \
  #       id:            'fd0e7e0d21b000d39716df5a46399cc4087137e2dbdb3de4ff4db907ce58b9df',
  #       confirmations: 4738,
  #       received_at:   Time.at(1523535100),
  #       entries:       [{ address: '2NA6umNrb57TCGGN2cj49sSdW5SzpcVaqYB', amount: 0.00050000.to_d }]
  #   end
  # end
  #
  # describe 'create_withdrawal!' do
  #   let(:issuer) { { address: '2NCugEoy5CsCbcqpB7EzZSo3Wbv2hSuegcb' } }
  #   let(:recipient) { { address: '2N7r9zKXkypzqtXfWkKfs3uZqKbJUhdK6JE' } }
  #   subject { client.create_withdrawal!(issuer, recipient, 0.01) }
  #
  #   let :set_fee_request_body do
  #     { jsonrpc: '1.0', method: 'settxfee', params: [0.65] }.to_json
  #   end
  #
  #   let :set_fee_response_body do
  #     { result: true }.to_json
  #   end
  #
  #   let :create_tx_request_body do
  #     { jsonrpc: '1.0', method: 'sendtoaddress', params: ['2N7r9zKXkypzqtXfWkKfs3uZqKbJUhdK6JE', 0.01] }.to_json
  #   end
  #
  #   let :create_tx_response_body do
  #     { result: 'dcedf50780f251c99e748362c1a035f2916efb9bb44fe5c5c3e857ea74ca06b3' }.to_json
  #   end
  #
  #   before do
  #     stub_request(:post, 'http://127.0.0.1:18332/').with(body: set_fee_request_body).to_return(body: set_fee_response_body)
  #     stub_request(:post, 'http://127.0.0.1:18332/').with(body: create_tx_request_body).to_return(body: create_tx_response_body)
  #   end
  #
  #   it { is_expected.to eq('dcedf50780f251c99e748362c1a035f2916efb9bb44fe5c5c3e857ea74ca06b3') }
  # end
end