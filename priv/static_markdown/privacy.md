Notice version 2, last updated 10th October 2026.

# Privacy

This site is hosted on Raspberry Pis in my house and I live in England. Northumberland to be reasonably precise. It's a personal website and from a privacy perspective, there's very little to go over if you're just a visitor, but you should keep reading to ensure you're not irked by anything I'm doing.

If you're using the subscribe feature I've got set up, then you really should keep reading, because in order to subscribe you need to tick the box that says you've read the privacy notice and that you're happy with everything in it. That's important.

Even though it's a personal website, I do talk about professional matters and link to (_and from_) my professional service sites. So there's a line of sight that puts me on the hook for complying with all of the data protection legislation around the world forever and ever and ever ever.

For the sake of clarity I, Jamie Curle (me@jamiecurle.com) would be considered the Data Controller and my business is a [registered data controller with the ICO](https://ico.org.uk/ESDWebPages/Entry/ZB503528). Note: I registered when my business was called Life of Treedom Limited. It is now called jamiecurle.ltd but the ICO don't let you change that. Hence, it's on as a trading name.

Here are the Data Processors that are used on this website.

## Data Processors

### Cloudflare

I use Cloudflare for a few things in this website. What about sovereignty I hear you claim? Honestly, I don't care. It's the internet, it's a personal website and I really don't care if it goes offline for a few hours or a few days. The world will continue just fine. But you might care that I use Cloudflare, and if you do, then you shouldn't use my website.

Here are the Cloudflare services that I use:

1. Cloudflare Tunnels - used for serving traffic.
2. Cloudflare R2 storage - used for storing photos and videos.
3. Cloudflare Turnstile - used on the subscribe page to limit bot traffic.

You should know that the Elixir processes that run this site are connected through a Cloudflare tunnel where it is terminated by Cloudflare and served to the internet. Images and video are served via Cloudflare also, using their R2 storage.

Obviously, this means that by visiting this site Cloudflare is going to do what Cloudflare does and for you that means that Cloudflare may place one or more cookies on your machine. You can read more about that on [Cloudflare's Cookie](https://developers.cloudflare.com/fundamentals/reference/policies-compliances/cloudflare-cookies/) page.

These cookies are strictly necessary for Cloudflare to provide its service and data collected is processed using legitimate interest.

Turnstile is how I keep bots off the subscribe form. To decide whether you're a human, it looks at signals from your browser and device and does its checks in the background; usually you won't see anything at all. Its script only loads on the subscribe page, nowhere else on the site. That's processed using legitimate interest: keeping the mailing list free of junk sign-ups, and not mailing people who never asked.


### Postmark

If you subscribe to this website, then you should know that I use Postmark to send the emails. They're based in the US (_Postmark is run by ActiveCampaign_). In order to send you an email, I have to send that data through Postmark and they (_obviously_) process that personal data.

Open tracking and link tracking are switched off. I don't know whether you opened an email or clicked anything in it, and I don't want to.

Postmark keeps a copy of each email and its delivery history (delivered, bounced and so on) for 45 days, then deletes it. It also keeps its own list of addresses that hard bounced or complained, so it doesn't mail them again.

You can read Postmark's [Privacy Policy](https://www.activecampaign.com/legal/privacy-policy), as well as their dedicated [EU GDPR information](https://postmarkapp.com/eu-privacy).


### Backblaze

I take hourly backups of this site and store them on Backblaze; the backups are encrypted as a blob, encrypted in transit and encrypted at rest. Backblaze is a US company, but the backups are stored in its EU region, so the data itself sits in the EU. You can read [Backblaze's privacy information on their website](https://www.backblaze.com/company/policy/privacy).

The data I process in backups is done so using legitimate interest.


### Retention Period

The backups live for 60 days and then they're deleted permanently. Not even your God(s), if you have them, or Science, if that's your thing, could restore that data. Perhaps Gods and Science could. That's a team I'd bat for.


## Data Collected

### Analytics

I don't store any personal data about any visitor. I use home rolled analytics that logs the url of the page visited, the date of the visit, any referrer present in the request, the kind of browser, operating system and device (e.g. "Firefox, macOS, desktop", worked out from the user agent) and, if set by Cloudflare, the country of the visitor.

To count unique visitors without storing your IP address, each visit also gets a one-way hash made from your IP address, your user agent and a secret that changes every day. The IP address is used for that moment to make the hash and is never stored. Because the secret changes daily, the same person gets a different hash tomorrow, so the hash can't be used to follow anyone over time, and it can't be turned back into an IP address.

Analytics Data is processed using legitimate interest.

#### Retention Period

I keep my analytics data in perpetuity so that I can gauge the performance of the website. But again, there's nothing to identify you in any of that data.


### Subscribers

If you subscribe to this website, I will store your email address and process it using the consent you've given when you subscribed. Just to be double sure I have that consent, I operate a double opt-in. I know it's a chore, but it keeps everything nice and neat.

Alongside your email address I store:

1. The worlds you picked and how often you want to hear from me.
2. When you ticked the consent box, and which version of this privacy notice you agreed to.
3. When the confirmation email was sent and when you confirmed.
4. When I last sent you a digest, which posts were in each one, and how many times in a row mail to you has soft bounced (a full mailbox, say), so I can stop sending if your address has stopped working.

You can withdraw your consent at any time. Every email has a link to unsubscribe, or to change what you get, and unsubscribing takes one click.

#### Delivery records and the do-not-mail list

Postmark tells me what happened to each email: delivered, bounced, or marked as spam. I keep those reports for 400 days so I can make sure mail from this site keeps arriving and isn't annoying anyone. In those reports your email address is replaced by a one-way keyed hash, so they don't contain your address itself. That's processed using legitimate interest.

If an email to you hard bounces, or you mark one as spam, I keep a keyed hash of your address on a do-not-mail list so it's never mailed again, even if someone tries to sign it up later. That's kept for as long as the mailing list exists. It's processed using legitimate interest, and it's the one thing I can't delete on request, because deleting it would defeat its purpose (_it's there to protect you_).

#### Retention Period.

If you sign up but never confirm, your sign-up is deleted after 7 days.

As soon as you unsubscribe, your email address and everything stored alongside it is deleted from the database. What remains is the delivery reports above (_hashed, and no longer linked to you_) until they reach 400 days old, and a record that a digest went out, with no link back to you. Your address does however live in the encrypted backups for 60 days.


## Security

All data on this site is stored on a Raspberry Pi, that now lives in my loft, in a locked network cabinet that only I can access. Specifically the data is in a Postgres database protected by various physical and technical controls including but not limited to:

1. Several access doors - normally locked, unless it's a nice day or I'm airing the house.
2. A loft hatch - always locked, unless I'm up there and it requires ladders.
3. Encrypted disks - should the Pi be stolen, the second someone tries to boot it, they'll need the encryption password. If they don't have it, they cannot access the disk.
4. Limited user access and segregated networks - I don't run the server stuff on the same generic network as everything else.
5. Two humans and two cats live in the house. We have a very strict challenge policy in our house. You won't make it in uninvited by a human and I can guarantee you'd have to be pretty nifty to remain un-ejected.
6. The cats, could in theory be bribed with food and catnip but you'd still have to get past me and either steal the Pi and keep it powered on (_challenging, but possible_) or get onto the right network

Obviously, this is an unusual setup. So if you're not comfortable with it, you probably shouldn't use my website.


## Automated Decisions

None. Nothing on this site makes decisions about you automatically, and there's no profiling.


## Transfer Mechanisms

One thing worth noting is that I am in the UK and Cloudflare and Postmark are US based companies. The data is transferred from the UK to the US using the [UK-US Data Bridge](https://www.gov.uk/government/publications/uk-us-data-bridge-supporting-documents/uk-us-data-bridge-factsheet-for-uk-organisations) adequacy decision transfer mechanism; both are certified under the UK Extension to the EU-US Data Privacy Framework.

Backblaze is also a US company, but the backups are stored in the EU, which is covered by the UK's adequacy regulations for the EU.


## Your Rights

I love that you have them and you absolutely can exercise your rights. Just email <a href="mailto:me@jamiecurle.com">me@jamiecurle.com</a> and let me know what right you wish to exercise. I'll answer within one month.

So that we're clear here's the rights you have and how you can exercise them.

1. The right to be informed - that's this notice.
2. The right of access - ask and I'll send you everything I hold about you.
3. The right to rectification - if something's wrong, I'll fix it. You can change your email preferences yourself from the link in any email.
4. The right to erasure - unsubscribing deletes your subscription straight away, or ask me. The one exception is the do-not-mail list described above.
5. The right to restrict processing - ask and I'll stop using your data while we sort out whatever's wrong.
6. The right to data portability - ask and I'll send you your data in a common format.
7. The right to object - you can object to anything I process using legitimate interest.
8. The right to withdraw consent - at any time, by unsubscribing from any email. It doesn't affect anything done before you withdrew it.

So that's pretty much it. Last updated on the 10th October 2026. If you want to grumble, moan or complain, you can do that through the [ICO](https://ico.org.uk/make-a-complaint/) but drop me an email first at me@jamiecurle.com and see if we can fix it between us.
