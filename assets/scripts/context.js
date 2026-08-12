(function(document){
    var context = {
        "@context": "http://schema.org",
        "@type": "MusicGroup",
        "@id": "https://bitbear.music",
        "name": "Bitbear",
        "description": "Bitbear is Asbjørn Ulsberg's tone-hammering, beat-juggling and demoscene-participating alter ego.",
        "logo": {
            "@type": "ImageObject",
            "url": "https://bitbear.music/assets/images/logo.svg"
        },
        "url": "https://bitbear.music",
        "genre": [
            "Electronic",
            "Synthwave"
        ],
        "sameAs": [
            "https://www.facebook.com/bitbearmusic",
            "https://twitter.com/bitbearmusic",
            "https://www.instagram.com/bitbearmusic",
            "https://www.youtube.com/channel/UC9wb6OrUrugGg6-q9805RDQ",
            "https://soundcloud.com/bitbear",
            "http://dj.beatport.com/bitbear",
            "https://www.mixcloud.com/bitbearmusic/",
            "https://bitbearmusic.bandcamp.com",
            "https://urort.p3.no/artist/Bitbear",
            "https://icosahedron.website/@bitbear",
            "https://mastodon.social/@bitbear",
            "https://modarchive.org/index.php?request=view_profile&query=84875"
        ],
        "member": [
            {
                "@type": "OrganizationRole",
                "member": {
                    "@type": "Person",
                    "name": "Artist",
                    "givenName": "Asbjørn Ulsberg",
                    "sameAs": [
                        "https://asbjor.nu/",
                        "https://twitter.com/asbjornu",
                        "https://www.last.fm/user/asbjornu"
                    ]
                },
                "roleName": [ "producer" ]
            }
        ]
    }
    var script = document.createElement('script');
    script.type = "application/ld+json";
    script.innerHTML = JSON.stringify(context);
    document.getElementsByTagName('head')[0].appendChild(script);
})(document);
