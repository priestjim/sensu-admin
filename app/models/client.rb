class Client < Resting

  def self.full_hash
    clienthash = {}
    Client.all.each{|c| clienthash[c.name] = { :address => c.address, :environment => c.environment}}
    clienthash
  end

  def environment
    @environment || "N/A"
  end

  def primary_role
    @primary_role || "N/A"
  end

end
