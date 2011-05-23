Geppetto is a simple command line tool to help manage Facebook test users and the generation of content.

## Installation

<pre class="terminal">
$ gem install geppetto
</pre>

## Usage

### Help

<pre class="terminal">
$ geppetto help
</pre>

### Common Scenarios

First let's start by creating a network of 5 friends.

<pre class="terminal">
$ geppetto create 5 --networked
</pre>

For each user, you will get a <code>login_url</code>, <code>id</code> and <code>access_token</code>. The <code>login_url</code> is useful to view this user on the facebook.com site. Otherwise, you can simply use the <code>access_token</code> to authenticate them within your own application.

<img src="http://cdn.ternarylabs.com/media/2011/03/fb_new_user.png">

<p class="caption">
A new test user. Test users seem to always be female.
</p>

To list all your test users, simply type:

<pre class="terminal">
$ geppetto list
</pre>

Now it's time to create some content by having all the users in the network update their status.

<pre class="terminal">
$ geppetto generate_status
</pre>

<img src="http://cdn.ternarylabs.com/media/2011/03/fb_status_update.png">

<p class="caption">
A new status update.
</p>

Let's engage in some social interactions. Each user will comment and like each other's posts.

<pre class="terminal">
$ geppetto generate_comments
$ geppetto generate_likes
</pre>

<img src="http://cdn.ternarylabs.com/media/2011/03/fb_like.png">

<p class="caption">
Liking and commenting.
</p>

You can also create and upload "photos".

<pre class="terminal">
$ geppetto generate_images
</pre>

<img src="http://cdn.ternarylabs.com/media/2011/03/fb_photo.png">

<p class="caption">
A photo is posted.
</p>

Geppetto provides a couple of shortcuts to populate content.

<pre class="terminal">
$ geppetto build
</pre>

Will build a network of test users and generate posts, likes, comments and images.

<pre class="terminal">
$ geppetto frenzy
</pre>

Frenzy mode will continuously generate random content until you terminate the application.
