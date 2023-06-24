class BirdsController < ApplicationController

  # GET /birds
  def index
    birds = Bird.all
    render json: birds
  end

  # POST /birds
  def create
    bird = Bird.create(bird_params)
    render json: bird, status: :created
  end

  # GET /birds/:id
def show
  bird = find_bird
  if bird
    render json: bird
  else
    render_not_found_response
  end
end

  # PATCH /birds/:id
  def update
    bird = find_bird
    if bird
      bird.update(bird_params)
      render json: bird
    else
      render_not_found_response
    end
  end

  # PATCH /birds/:id/like
  def increment_likes
    bird = Bird.find_by(id: params[:id])
    if bird
      bird.update(likes: bird.likes + 1)
      render json: bird
    else
      render json: { error: "Bird not found" }, status: :not_found
    end
  end

  # DELETE /birds/:id
  def destroy
    bird = Bird.find_by(id: params[:id])
    if bird
      bird.destroy
      head :no_content
    else
      render json: { error: "Bird not found" }, status: :not_found
    end
  end

  private

  def bird_params
    params.permit(:name, :species, :likes)
  end

  def render_not_found_response
    render json: { error: "Bird not found" }, status: :not_found
  end

  def find_bird
    Bird.find(params[:id])
  end

end
