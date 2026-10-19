const icons = {
  camera:'<path d="M4 6.5h3l1.8-2h6.4l1.8 2h3a1.5 1.5 0 0 1 1.5 1.5v11a1.5 1.5 0 0 1-1.5 1.5H4A1.5 1.5 0 0 1 2.5 19V8A1.5 1.5 0 0 1 4 6.5Z"/><circle cx="12" cy="13" r="4"/>',
  music:'<path d="M9 17.5V5l10-2v12.5M9 8l10-2"/><ellipse cx="6" cy="17.5" rx="3" ry="2.5"/><ellipse cx="16" cy="15.5" rx="3" ry="2.5"/>',
  photos:'<rect x="6" y="7" width="15" height="14" rx="2.5"/><path d="M3 16V5.5A2.5 2.5 0 0 1 5.5 3H16M6 17l4-4 3.5 3 2-2 5.5 5"/><circle cx="16.5" cy="11" r="1"/>',
  folder:'<path d="M3 7V5a2 2 0 0 1 2-2h5l2 3h7a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7h17"/>',
  settings:'<path d="m10 3-.7 2.4-2 .8-2.3-1.1-2 3.5 2 1.5-.1 2.2L3 14l2 3.5 2.4-.8 1.8 1.2L10 21h4l.8-2.4 1.8-1.2 2.4.8 2-3.5-1.9-1.7-.1-2.2 2-1.5-2-3.5-2.3 1.1-2-.8L14 3Z"/><circle cx="12" cy="12" r="3"/>',
  arrow:'<path d="m9 5 7 7-7 7"/>',
  close:'<path d="m7 7 10 10M17 7 7 17"/>'
};
function iconMarkup(name) { return `<svg viewBox="0 0 24 24" aria-hidden="true">${icons[name] || ''}</svg>`; }
function paintIcons(root = document) { root.querySelectorAll('[data-icon]').forEach(node => { node.innerHTML = iconMarkup(node.dataset.icon); }); }
paintIcons();
const photos = {
  coast:{file:'coast.jpg',alt:'夕暮れの海沿いの線路',date:'2026年10月18日 17:42',song:'風をあつめて',artist:'はっぴいえんど'},
  beach:{file:'beach.jpg',alt:'山に囲まれた青い入り江',date:'2026年10月12日 14:18',song:'水平線',artist:'back number'},
  cafe:{file:'cafe.jpg',alt:'自然光の入る窓辺の喫茶店',date:'2026年10月4日 15:06',song:'音楽なし',artist:''}
};
document.querySelectorAll('[data-photo]').forEach(button => {
  button.addEventListener('click', () => {
    const photo = photos[button.dataset.photo];
    const screen = button.closest('.screen');
    if(screen.querySelector('.photo-overlay')) return;
    const overlay = document.createElement('div');
    overlay.className = 'photo-overlay';
    overlay.setAttribute('role','dialog');
    overlay.setAttribute('aria-modal','true');
    overlay.setAttribute('aria-label','写真の拡大表示');
    overlay.innerHTML = `<div class="overlay-top"><h2>写真</h2><button class="close" aria-label="閉じる"><i data-icon="close"></i></button></div><img class="full-photo" src="assets/${photo.file}" alt="${photo.alt}"><p class="overlay-date">${photo.date}</p><p class="overlay-song">${photo.song}</p>${photo.artist ? `<p class="overlay-artist">${photo.artist}</p>` : ''}`;
    paintIcons(overlay);
    screen.append(overlay);
    const page = screen.querySelector('.page');
    page.inert = true;
    const close = () => { overlay.remove(); page.inert = false; button.focus({preventScroll:true}); };
    overlay.querySelector('.close').addEventListener('click', close);
    overlay.addEventListener('keydown', event => {
      if(event.key === 'Escape') close();
      if(event.key === 'Tab') { event.preventDefault(); overlay.querySelector('.close').focus({preventScroll:true}); }
    });
    overlay.querySelector('.close').focus({preventScroll:true});
  });
});
