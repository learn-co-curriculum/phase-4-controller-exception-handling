# Controller Exception Handling

## Learning Goals

- Use exception handling techniques like `rescue` and `rescue_from` in a Rails
  controller

## Introduction

In this lesson, we'll finish work on our Bird API by refactoring the controller
to add in some helpful reusable error handling code. To get set up, run:

```console
$ bundle install
$ rails db:migrate db:seed
$ rails s
```

This will download all the dependencies for our app, set up the database, and
run the Rails server.

## Video Walkthrough

<iframe width="560" height="315" src="https://www.youtube.com/embed/evlSdyGoE3s?rel=0&showinfo=0" frameborder="0" allowfullscreen></iframe>

## DRYing Up Controller Code

In the current implementation of our `BirdsController`, we've defined actions to
handle all five RESTful routes plus one additional custom route. You'll notice
there is some common behavior between a lot of the methods. For all the routes
that include a route parameter (`/birds/:id`), we're using the ID in the params
hash to look up a bird; if the bird is found, we're performing some action with
it, and if not, we're sending an error message back.

For example, have a look at the `show` and `update` actions:

```rb
# GET /birds/:id
def show
  bird = Bird.find_by(id: params[:id])
  if bird
    render json: bird
  else
    render json: { error: "Bird not found" }, status: :not_found
  end
end

# PATCH /birds/:id
def update
  bird = Bird.find_by(id: params[:id])
  if bird
    bird.update(bird_params)
    render json: bird
  else
    render json: { error: "Bird not found" }, status: :not_found
  end
end
```

Between these two methods, there's a good amount of repeated code:

- Finding a bird based on the ID
- Performing control flow (if/else) based on whether or not the bird exists
- Returning an error message with a status of `:not_found` if the bird doesn't
  exist

That same code also exists in the `increment_likes` and `destroy` actions. That
makes this a good opportunity for a refactor to DRY up some of this repeated
logic!

Let's start by making a private method for generating the `:not_found` response:

```rb
private

def render_not_found_response
  render json: { error: "Bird not found" }, status: :not_found
end
```

We can then update our actions to use this method instead of implementing the
rendering logic directly:

```rb
# GET /birds/:id
def show
  bird = Bird.find_by(id: params[:id])
  if bird
    render json: bird
  else
    render_not_found_response
  end
end

# PATCH /birds/:id
def update
  bird = Bird.find_by(id: params[:id])
  if bird
    bird.update(bird_params)
    render json: bird
  else
    render_not_found_response
  end
end
```

We can also make a helper method to find a bird based on the ID in the params
hash:

```rb
private

def find_bird
  Bird.find_by(id: params[:id])
end
```

Now, our controller actions don't need to worry about how the `find_bird` method
is implemented, as long as it returns a bird from the database. This frees us up
to change how the bird finding logic is implemented in the future (for example,
using something other than the ID to look up a bird in the database, like a URL
slug or [UUID][uuid]).

Here's how our controller actions can use this method:

```rb
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
```

## Handling Exceptions

We can also shorten up the code in each of our controller methods by using a
different approach to finding a bird using the ID. This will also help us
improve our error handling. Currently, we're using the [`find_by`][find_by]
method to look up a bird. `find_by` returns `nil` if the record isn't found in
the database, which makes it useful for `if/else` control flow, since `nil` is a
false-y value in Ruby.

If we use the [`find`][find] method instead, we'll get an
`ActiveRecord::RecordNotFound` exception instead of `nil` when the record
doesn't exist. Try updating the `find_bird` action like this:

```rb
def find_bird
  Bird.find(params[:id])
end
```

Then make a request for an ID that doesn't exist in the database, like
`localhost:3000/birds/9999`. You should see an error message like this:

```txt
ActiveRecord::RecordNotFound (Couldn't find Bird with 'id'=9999)
```

We can handle this error in our controller method by using a
[`rescue` block in our method][ruby method exception syntax], like so:

```rb
def show
  bird = find_bird
  render json: bird
rescue ActiveRecord::RecordNotFound
  render_not_found_response
end
```

Not only is this code shorter than the previous implementation, it also gives a
clearer separation between the "happy path" of our code (no exceptions/errors)
and the logic for handling exceptions/errors. Try making the same request in the
browser to `localhost:3000/birds/9999` — now that we're handling the exception
in the controller, you should see a 404 status code in the console with the `{ "error": "Bird not found" }` JSON response instead of a 500 server error.

We use the same approach to our `update` action as well:

```rb
def update
  bird = find_bird
  bird.update(bird_params)
  render json: bird
rescue ActiveRecord::RecordNotFound
  render_not_found_response
end
```

The tradeoff to this approach of using exception handling rather than an if/else
control flow is that it may be less apparent to other developers looking at our
code at first what code in the `update` block would cause that exception to be
thrown.

We can take this one step further, and use the [`rescue_from` method][rescue_from]
to handle the `ActiveRecord::RecordNotFound` exception from **all** of our controller
actions:

```rb
class BirdsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found_response

  # rest of controller...
end
```

By using the `rescue_from` method this way, if _any_ of our controller actions
throw an `ActiveRecord::RecordNotFound` exception, our
`render_not_found_response` method will return the appropriate JSON response.

Here's the fully refactored version of the controller:

```rb
class BirdsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found_response

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
    render json: bird
  end

  # PATCH /birds/:id
  def update
    bird = find_bird
    bird.update(bird_params)
    render json: bird
  end

  # PATCH /birds/:id/like
  def increment_likes
    bird = find_bird
    bird.update(likes: bird.likes + 1)
    render json: bird
  end

  # DELETE /birds/:id
  def destroy
    bird = find_bird
    bird.destroy
    head :no_content
  end

  private

  def find_bird
    Bird.find(params[:id])
  end

  def bird_params
    params.permit(:name, :species, :likes)
  end

  def render_not_found_response
    render json: { error: "Bird not found" }, status: :not_found
  end

end
```

## Conclusion

Using exception handling techniques like `rescue` and `rescue_from` opens up a
lot of possibilities in terms of how you structure your code. For our controller
actions in particular, it allows us to isolate the "happy path" of our code
(performing CRUD actions and rendering a response to the users) from the
exception handling logic. It also lets us handle exceptions in a consistent way,
so that users of our API get the same response for common errors, like not being
able to find a particular resource.

## Check For Understanding

Before you move on, make sure you can answer the following questions:

1. What is the difference in behavior between the `find` and `find_by` methods?
   Why is that difference important for how we handle not-found errors?
2. Looking at the final version of the controller code, what sequence of events
   would happen if we tried to submit a `PATCH` request for a bird that doesn't
   exist?

## Resources

- [`rescue_from` method][rescue_from]

[uuid]: https://en.wikipedia.org/wiki/Universally_unique_identifier
[find_by]: https://api.rubyonrails.org/v6.1.3.2/classes/ActiveRecord/FinderMethods.html#method-i-find_by
[find]: https://api.rubyonrails.org/v6.1.3.2/classes/ActiveRecord/FinderMethods.html#method-i-find
[ruby method exception syntax]: https://ruby-doc.org/core-2.7.3/doc/syntax/exceptions_rdoc.html
[rescue_from]: https://api.rubyonrails.org/classes/ActiveSupport/Rescuable/ClassMethods.html#method-i-rescue_from
