ENV['RACK_ENV'] ||= 'development'

require 'sinatra/base'
require 'sinatra/flash'
require_relative 'data_mapper_setup'


class MakersBnb < Sinatra::Base
  use Rack::MethodOverride

  register Sinatra::Flash
  set :public_folder, proc { File.join(root, '..', 'public') }
  enable :sessions
  set :session_secret, 'MakersBnb super secret'

  get '/' do
    redirect to('/listings')
  end

  get '/listings' do
    @spaces = Space.all
    erb :spaces
  end

  get '/space/add' do
    erb :add_space
  end

  post '/space' do
    Space.create(name: params[:name],
    location: params[:location],
    description: params[:description],
    price: params[:price],
    available_from: params[:available_from],
    available_to: params[:available_to],
    user: current_user)

    redirect '/sessions/user/spaces'
  end

  get '/space/edit' do
    @edit_space = Space.get(params[:space_id])
    erb :'sessions/user/edit'
  end

  post '/space/update' do
    update_space = Space.get(params[:space_id])
    update_space.update(name: params[:name],
    location: params[:location],
    description: params[:description],
    price: params[:price])
    redirect '/sessions/user/spaces'
  end

  post '/space/delete' do
    delete_space = Space.get(params[:space_id])
    delete_space.destroy
    redirect to('/sessions/user/spaces')
  end

  get '/user/new' do
    if !current_user
      @user = User.new
      erb :'user/new'
    else
      flash.keep[:notice] = 'Please log out to create a new user!'
      redirect('/listings')
    end
  end

  post '/user' do
    @user = User.create(
    first_name: params[:first_name],
    surname: params[:surname],
    email: params[:email],
    password: params[:password],
    password_confirmation: params[:password_confirmation]
    )

    if @user.save
      session[:user_id] = @user.id
      redirect to('/listings')
    else
      flash.now[:errors] = @user.errors.full_messages
      erb :'user/new'
    end
  end

  get '/sessions/new' do
    if !current_user
      erb :'sessions/new'
    else
      flash.keep[:notice] = "Already signed in!"
      redirect to ("/listings")
    end
  end

  post '/sessions' do
    user = User.authenticate(params[:email], params[:password])
    if user
      session[:user_id] =user.id
      redirect to('/listings')
    else
      flash.now[:errors] = ['The email or password is incorrect']
      erb :'sessions/new'
    end
  end

  get '/sessions/user/spaces' do
    if !current_user
      erb :'listings'
    else
      @user_spaces = Space.all(user: current_user)
      erb :'sessions/user/spaces'
    end
  end

  delete '/sessions' do
    session[:user_id] = nil
    flash.keep[:notice] = 'Goodbye!'
    redirect to('/listings')
  end

  post '/book' do

    if !current_user
      flash.keep[:notice] = "Please log in or sign up to request a space"
      redirect to '/listings'
    else
      @booking = Booking.new(
      check_in: params[:check_in],
      check_out: params[:check_out],
      space_id: params[:space_id],
      user: current_user)

      requested_dates = Booking.booking_range(@booking.check_in, @booking.check_out)
      all_bookings = Booking.all_space_booking(@booking.space_id)
      all_booked_dates = Booking.space_bookings(all_bookings)

      if all_bookings.empty?
        @booking.save
        flash.keep[:notice] = "Thank you. Your request has been sent!"
        redirect to '/listings'
      elsif Booking.check_available(requested_dates, all_booked_dates)
        flash.keep[:notice] = "Sorry the space is already booked for those days"
        redirect to '/listings'
      else
        @booking.save
        flash.keep[:notice] = "Thank you. Your request has been sent!"
        redirect to '/listings'
      end
    end
  end

  get '/sessions/user/spaces/requests' do
    @requests = Booking.all(space: Space.all(user: current_user))
    erb :'sessions/user/requests'
  end

  post '/confirm' do
    confirm_booking = Booking.get(params[:booking_id])
    confirm_booking.update(confirmed: true)
    flash.keep[:notice] = 'Thank you for confirming this booking'
    redirect to '/sessions/user/spaces/requests'
  end

  post '/reject' do
    reject_booking = Booking.get(params[:booking_id])
    reject_booking.destroy
    flash.keep[:notice] = 'You have rejected this request'
    redirect to '/sessions/user/spaces/requests'
  end

  helpers do
    def current_user
      @current_user ||= User.get(session[:user_id])
    end
  end

  # start the server if ruby file executed directly
  run! if app_file == $0
end
