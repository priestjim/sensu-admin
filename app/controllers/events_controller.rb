class EventsController < ApplicationController
  before_filter :find_events, :only => [:index, :events_table ]
  before_filter :prepare_for_mobile

  def index
  end

  def events_table
    events_datatable = []
    @events.each_with_index do |event, i|
      events_datatable << [
       event.sort_val,
       render_to_string(:action => "_status", :formats => [:html], :layout => false, :locals => { :event => event }),
       event.client_attributes['environment'],
       event.client,
       event.check,
       render_to_string(:action => "_output", :formats => [:html], :layout => false, :locals => { :event => event }),
       render_to_string(:action => "_actions", :formats => [:html], :layout => false, :locals => { :event => event, :i => i}),
       render_to_string(:action => "_issued", :formats => [:html], :layout => false, :locals => { :event => event }),
       "<div class = 'moreinfo' style = 'cursor: pointer; position: absolute; display: block; height: 25px; width: 25px;' index_id='#{i}' misc='#{event.client}_#{event.check}'><i style='padding-right: 10px;' class='icon-zoom-in'></i></div>"
      ]
    end
    respond_to do |format|
      format.json do
        render :json => { "aaData" => events_datatable}
      end
    end
  end

  def modal_data
    event = Event.single(params[:event_query])
    render :json => {:data => render_to_string(:action => "_modal_data", :layout => false, :locals => {:event => event, :i => params[:i]})}
  end

  def resolve
    resp = Event.manual_resolve(params[:client], params[:check], current_user)
    Event.refresh_cache
    respond_to do |format|
      format.json { render :json => (resp.code == 202).to_s }
      format.mobile { render :json => (resp.code == 202).to_s }
    end
  end

  def silence_client
    expire_at = nil
    if !params[:expire_at_time].blank? && !params[:expire_at_date].blank?
      expire_at = Time.parse("#{params[:expire_at_date]} #{params[:expire_at_time]}")
    end
    params[:description] = "No reason given" if params[:description].empty?
    resp = Event.silence_client(params[:client], params[:description], current_user, expire_at)
    Stash.refresh_cache
    respond_to do |format|
      format.json { render :json => (resp.code == 201).to_s }
      format.mobile { render :json => (resp.code == 201).to_s }
    end
  end

  def silence_check
    expire_at = nil
    if !params[:expire_at_time].blank? && !params[:expire_at_date].blank?
      expire_at = Time.parse("#{params[:expire_at_date]} #{params[:expire_at_time]}")
    end
    params[:description] = "No reason given" if params[:description].empty?
    resp = Event.silence_check(params[:client], params[:check], params[:description], current_user, expire_at)
    Stash.refresh_cache
    respond_to do |format|
      format.json { render :json => (resp.code == 201).to_s }
      format.mobile { render :json => (resp.code == 201).to_s }
    end
  end

  def unsilence_client
    resp = Event.unsilence_client(params[:client], current_user)
    Stash.refresh_cache
    respond_to do |format|
      format.json { render :json => (resp.code == 202).to_s }
      format.mobile { render :json => (resp.code == 202).to_s }
    end
  end

  def unsilence_check
    resp = Event.unsilence_check(params[:client], params[:check], current_user)
    Stash.refresh_cache
    respond_to do |format|
      format.json { render :json => (resp.code == 202).to_s }
      format.mobile { render :json => (resp.code == 202).to_s }
    end
  end

  private

  def find_events
    events = Event.all_with_cache
    stashes = Hash[Stash.stashes.select {|stash, value| stash =~ /silence/}]
    cli = {}
    Client.all_with_cache.each do |client|
      cli[client.name] = JSON.parse(client.to_json)
    end
    events.each do |event|
      if stashes.include?("silence/#{event.client}")
        event.client_silenced = stashes["silence/#{event.client}"]
      end
      if stashes.include?("silence/#{event.client}/#{event.check}")
        event.check_silenced = stashes["silence/#{event.client}/#{event.check}"]
      end

      #
      # Just in case we got into a condition where a new event appeared to a new client, but was not cached yet.
      # This isnt an issue though as client_attributes in Event will fail back to getting fresh json from API
      #
      unless cli[event.client].nil?
        event.client_attributes = cli[event.client]
      end
    end
    @events = events
  end
end
