module Agents
  class BattlenetVersionCheckerAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description do
      <<-MD
      The Battlenet Version Checker Agent checks if a new version is available for games and creates an event if found.

      `debug` is used for verbose mode.

      `diablo4` can be enabled to monitore new releases about this game.

      `cod_mw2_wz2` can be enabled to monitore new releases about this game.

      `region` can be eu, us or kr.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "Region": "eu",
            "BuildConfig": "849b3cbba08ee5a78173a8bed156909e",
            "CDNConfig": "cf3e51475b3258e18fc53c115021381b",
            "KeyRing": "",
            "BuildId": "42016",
            "VersionName": "1.0.2.42016",
            "ProductConfig": "bb943b96ed03cafe783d31dc3d5ee155",
            "Game": "Diablo IV"
          }
    MD

    def default_options
      {
        'debug' => 'false',
        'diablo4' => 'true',
        'cod_mw2_wz2' => 'true',
        'expected_receive_period_in_days' => '15',
      }
    end

    form_configurable :debug, type: :boolean
    form_configurable :diablo4, type: :boolean
    form_configurable :cod_mw2_wz2, type: :boolean
    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :region, type: :array, values: ['eu', 'us', 'kr']
    def validate_options
      errors.add(:base, "region has invalid value: should be 'eu', 'us', 'kr'") if interpolated['type'].present? && !%w(en us kr).include?(interpolated['region'])

      if options.has_key?('diablo4') && boolify(options['diablo4']).nil?
        errors.add(:base, "if provided, diablo4 must be true or false")
      end

      if options.has_key?('cod_mw2_wz2') && boolify(options['cod_mw2_wz2']).nil?
        errors.add(:base, "if provided, cod_mw2_wz2 must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      trigger_action
    end

    private

    def log_curl_output(code,body)

      log "request status : #{code}"

      if interpolated['debug'] == 'true'
        log "body"
        log body
      end

    end

    def compare(payload,game)

      payload = JSON.parse(payload)
      if !memory[game]
        payload.each do |result|
          if result["Region"] == interpolated['region']
            create_event payload: result
          end
        end
        memory[game] = payload
      else
        result = payload.select { |entry| entry['Region'] == interpolated['region'] }
        log result
        result_memory = memory[game].select { |entry| entry['Region'] == interpolated['region'] }
        if result != result_memory
          create_event payload: result[0]
          memory[game] = payload
        else
          if interpolated['debug'] == 'true'
            log "nothing to compare because same value"
          end
        end
      end  

    end

    def get_version(game,real_name)

      url = URI.parse("http://eu.patch.battle.net:1119/#{game}/versions")

      response = Net::HTTP.get_response(url)

      log_curl_output(response.code,response.body)

      lines = response.body.split("\n")
      results = []
      
      lines.each do |line|
        next if line.start_with?("Region")
        next if line.start_with?("## seqn")
      
        parts = line.split("|")
        region = parts[0]
        build_config = parts[1]
        cdn_config = parts[2]
        key_ring = parts[3]
        build_id = parts[4]
        version_name = parts[5]
        product_config = parts[6]
      
        result = {
          "Region" => region,
          "BuildConfig" => build_config,
          "CDNConfig" => cdn_config,
          "KeyRing" => key_ring,
          "BuildId" => build_id,
          "VersionName" => version_name,
          "ProductConfig" => product_config,
          "Game" => real_name
        }
      
        results << result
      end
      
      json_data = results.to_json
      
      if interpolated['debug'] == 'true'
        log json_data
      end

      compare(json_data,game)

    end

    def trigger_action

      if interpolated['diablo4'] == 'true'
        product_code = "fenris"
        real_name = "Diablo IV"
        get_version(product_code,real_name)
      end
      if interpolated['cod_mw2_wz2'] == 'true'
        product_code = "auks"
        real_name = "Call of Duty: MWII | WZ2.0"
        get_version(product_code,real_name)
      end
    end
  end
end
