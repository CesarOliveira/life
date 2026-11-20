module Places
  # Liga visitas ao lugar nomeado mais próximo que as cobre (raio + imprecisão).
  class Matcher
    def initialize(account)
      @account = account
      @places = account.places.to_a
    end

    def place_for(lat, lng, accuracy_m = nil)
      @places.select { |p| p.covers?(lat, lng, accuracy_m) }.min_by { |p| p.distance_to(lat, lng) }
    end

    def assign_unassigned
      return 0 if @places.empty?

      count = 0
      @account.visits.unassigned.find_each do |visit|
        place = place_for(visit.lat, visit.lng, visit.accuracy_m)
        next unless place

        visit.update_columns(place_id: place.id, updated_at: Time.current)
        count += 1
      end
      count
    end

    # Depois de criar/mover/redimensionar um lugar: refaz as ligações de todas as visitas.
    def reassign_all
      @account.visits.update_all(place_id: nil)
      assign_unassigned
    end
  end
end
