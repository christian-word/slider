﻿<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <title>Именинники недели</title>
  <style>
    body {
      margin: 0;
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: #fff;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-direction: column;
    }
    .loading, .error, .upload, .no-birthdays, .info-list {
      text-align: center;
      padding: 30px;
      background: rgba(255,255,255,0.1);
      backdrop-filter: blur(10px);
      border-radius: 20px;
      max-width: 800px;
      margin: 20px;
    }
    .upload {
      display: none;
      border: 3px dashed rgba(255,255,255,0.3);
      cursor: pointer;
    }
    .upload-btn, .retry-btn, .btn {
      background: linear-gradient(45deg, #ff6b6b, #ee5a24);
      border: none;
      color: white;
      padding: 15px 40px;
      font-size: 1.1em;
      border-radius: 50px;
      cursor: pointer;
      transition: all 0.3s ease;
      font-weight: 600;
      box-shadow: 0 4px 15px rgba(0,0,0,0.2);
      margin: 10px;
    }
    .slider {
      display: none;
      overflow: hidden;
      width: 100vw;
      height: 100vh;
      position: fixed;
      top: 0;
      left: 0;
      background: linear-gradient(135deg, #2c3e50 0%, #34495e 100%);
    }
    .slides-container {
      display: flex;
      width: 100%;
      height: 100%;
      transition: transform 0.8s ease;
    }
    .slide {
      min-width: 100%;
      height: 100%;
      display: flex;
      justify-content: space-around;
      align-items: center;
      flex-shrink: 0;
      padding: 20px;
    }
    .card {
      width: 48%;
      height: 90%;
      background: rgba(255,255,255,0.1);
      backdrop-filter: blur(20px);
      border-radius: 20px;
      padding: 20px;
      display: flex;
      flex-direction: column;
      align-items: center;
      box-shadow: 0 8px 32px rgba(0,0,0,0.3);
      border: 1px solid rgba(255,255,255,0.2);
    }
    .single-card {
      width: 60%;
    }
    iframe {
      width: 100%;
      flex: 1;
      border: none;
      border-radius: 15px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.3);
    }
    .info {
      text-align: center;
      margin-top: 20px;
      font-size: 1.5em;
      font-weight: 600;
      text-shadow: 0 2px 4px rgba(0,0,0,0.5);
    }
    .info strong {
      display: block;
      margin-bottom: 5px;
      font-size: 1.2em;
      color: #ffd700;
    }
    .nav {
      position: absolute;
      top: 50%;
      width: 100%;
      display: flex;
      justify-content: space-between;
      transform: translateY(-50%);
      pointer-events: none;
      padding: 0 30px;
      z-index: 10;
    }
    .btn {
      background: rgba(255,255,255,0.2);
      backdrop-filter: blur(10px);
      border: none;
      color: white;
      font-size: 2em;
      padding: 20px 25px;
      cursor: pointer;
      pointer-events: auto;
      border-radius: 50%;
      transition: all 0.3s ease;
      box-shadow: 0 4px 15px rgba(0,0,0,0.2);
      border: 1px solid rgba(255,255,255,0.3);
    }
    .btn:hover {
      background: rgba(255,255,255,0.3);
      transform: scale(1.1);
      box-shadow: 0 6px 20px rgba(0,0,0,0.4);
    }
  </style>
</head>
<body>

<div class="loading" id="loading">
  <div style="font-size:4em">🎂</div>
  <div class="loading-text">Загружаем именинников...</div>
  <div>Подождите немного</div>
</div>

<div class="error" id="error" style="display: none;">
  <div style="font-size:4em;color:#ff6b6b">❌</div>
  <div style="font-size:1.5em;font-weight:600;margin-bottom:10px;color:#ff6b6b">Ошибка загрузки данных</div>
  <div id="error-message">Не удалось загрузить файл photo-database.json</div>
  <button class="retry-btn" onclick="retryLoad()">🔄 Повтор</button>
  <button class="retry-btn" onclick="showManualUpload()">📁 Загрузить</button>
</div>

<div class="upload" id="upload-area">
  <div style="font-size:4em">📁</div>
  <div style="font-size:1.5em;font-weight:600;margin-bottom:10px;">Загрузить файл вручную</div>
  <div>Перетащите JSON-файл с данными</div>
  <button class="upload-btn" onclick="selectFile()">📁 Выбрать файл</button>
</div>
<input type="file" id="file-input" accept=".json" style="display:none">

<div class="no-birthdays" id="no-birthdays" style="display: none;">
  <div style="font-size: 3em; margin-bottom: 20px;">😔</div>
  <div>Нет именинников на этой неделе</div>
  <button class="retry-btn" onclick="retryLoad()">🔄 Обновить</button>
</div>

<div class="info-list" id="info-list" style="display: none;"></div>

<div class="slider" id="slider">
  <div class="slides-container" id="slides-container"></div>
</div>
<div class="nav">
  <button class="btn" onclick="prevSlide()">❮</button>
  <button class="btn" onclick="nextSlide()">❯</button>
</div>

<script>
let slideIndex = 0, slides = [], people = [];

window.addEventListener('load', loadData);

window.startSlideshow = startSlideshow;
window.retryLoad = retryLoad;
window.selectFile = selectFile;

if (/Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent)) {
  window.addEventListener('DOMContentLoaded', () => {
    const interval = setInterval(() => {
      const checkbox = document.getElementById('fullscreen-checkbox');
      if (checkbox) {
        checkbox.checked = false;
        checkbox.disabled = true;
        clearInterval(interval);
      }
    }, 100);
  });
}

function retryLoad() { loadData(); }

function showManualUpload() {
  hideAll();
  document.getElementById('upload-area').style.display = 'block';
}

function selectFile() {
  document.getElementById('file-input').click();
}

document.getElementById('file-input').addEventListener('change', e => {
  if (e.target.files.length) handleFile(e.target.files[0]);
});

document.getElementById('upload-area').addEventListener('drop', e => {
  e.preventDefault();
  handleFile(e.dataTransfer.files[0]);
});

document.getElementById('upload-area').addEventListener('dragover', e => e.preventDefault());

function handleFile(file) {
  if (!file.name.endsWith('.json')) return alert('Файл має бути у форматі .json');
  const reader = new FileReader();
  reader.onload = e => {
    try {
      const json = JSON.parse(e.target.result);
      processData(json);
    } catch {
      showError('Помилка читання JSON-файлу');
    }
  };
  reader.readAsText(file);
}

function hideAll() {
  ['loading', 'error', 'upload-area', 'slider', 'no-birthdays', 'info-list'].forEach(id => {
    document.getElementById(id).style.display = 'none';
  });
}

function showError(msg) {
  hideAll();
  document.getElementById('error-message').textContent = msg;
  document.getElementById('error').style.display = 'block';
}

async function loadData() {
  try {
    hideAll();
    document.getElementById('loading').style.display = 'block';

    const BIN_ID = '6873f48a5fdad557dbe10d30'; // вставь свой
    const API_KEY = '$2a$10$foT8lIkBZ.MYNt758MsuJuBvxxI750/hg4QyQXX.Q7b2vu/G0/irm'; // вставь свой

    const res = await fetch(`https://api.jsonbin.io/v3/b/${BIN_ID}`, {
      headers: {
        'X-Master-Key': API_KEY
      }
    });

    if (!res.ok) throw new Error('HTTP ' + res.status);

    const json = await res.json();
    processData(json.record);
  } catch (e) {
    showError(e.message);
  }
}

function calculateAge(birthdate) {
  const birth = new Date(birthdate);
  const today = new Date();
  let age = today.getFullYear() - birth.getFullYear();
  const m = today.getMonth() - birth.getMonth();
  if (m < 0 || (m === 0 && today.getDate() < birth.getDate())) {
    age--;
  }
  return age;
}

function processData(data) {
  if (!Array.isArray(data.entries)) return showError('Відсутній масив entries у JSON');

  const today = new Date();
  const pastWeek = new Date(today);
  pastWeek.setDate(today.getDate() - 6);

  today.setHours(23, 59, 59, 999);
  pastWeek.setHours(0, 0, 0, 0);

  people = data.entries.filter(p => {
    if (!p.birthdate) return false;
    const [y, m, d] = p.birthdate.trim().split('-');
    const b = new Date(today.getFullYear(), parseInt(m) - 1, parseInt(d));
    return b >= pastWeek && b <= today;
  });

  if (!people.length) {
    hideAll();
    document.getElementById('no-birthdays').style.display = 'block';
    return;
  }

  const infoBlock = document.getElementById('info-list');
  infoBlock.innerHTML = `<h2>Знайдено ${people.length} осіб:</h2>` +
    '<ul style="list-style:none;padding:0">' +
    people.map(p => {
      const [y, m, d] = p.birthdate.trim().split('-');
      const birth = new Date(today.getFullYear(), parseInt(m) - 1, parseInt(d));
      const age = calculateAge(p.birthdate);
      return `<li style="margin:10px 0">${p.lastname}, ${birth.toLocaleDateString('uk-UA')} — ${age} років</li>`;
    }).join('') + '</ul>' +
    `<label style="display:block;margin:20px 0;font-size:1em;">
       <input type="checkbox" id="fullscreen-checkbox" style="transform:scale(1.5);margin-right:10px;" checked>
       Запустити в повноекранному режимі
     </label>` +
    '<button class="retry-btn" onclick="startSlideshow()">▶️ Почати показ</button>';

  hideAll();
  infoBlock.style.display = 'block';
}

function startSlideshow() {
  const fs = document.getElementById('fullscreen-checkbox');
  if (fs && fs.checked) requestFullscreen();

  document.getElementById('info-list').style.display = 'none';
  document.getElementById('slider').style.display = 'block';
  document.body.style.background = 'none';
  buildSlides();
}

function requestFullscreen() {
  const el = document.documentElement;
  if (el.requestFullscreen) el.requestFullscreen();
  else if (el.webkitRequestFullscreen) el.webkitRequestFullscreen();
  else if (el.msRequestFullscreen) el.msRequestFullscreen();
}

function buildSlides() {
  const container = document.getElementById('slides-container');
  container.innerHTML = '';
  slides = [];
  slideIndex = 0;

  for (let i = 0; i < people.length; i += 2) {
    const slide = document.createElement('div');
    slide.className = 'slide';

    const card1 = createCard(people[i]);
    slide.appendChild(card1);

    const person2 = people[i + 1];
    if (person2) {
      slide.appendChild(createCard(person2));
    } else {
      card1.classList.add('single-card');
    }

    container.appendChild(slide);
    slides.push(slide);
  }

  updateSlider();
}

function createCard(p) {
  const card = document.createElement('div');
  card.className = 'card';

  const img = document.createElement('img');
  img.className = 'fallback-image';
  img.src = `https://drive.google.com/thumbnail?id=${p.id}&sz=w500`;
  img.onerror = () => {
    img.src = 'https://raw.githubusercontent.com/christian-word/slider/main/4054617.png';
  };

  card.appendChild(img);

  const info = document.createElement('div');
  info.className = 'info';
  const age = calculateAge(p.birthdate);
  info.innerHTML = `
    <strong>${p.lastname}</strong>
    <div>${new Date(p.birthdate).toLocaleDateString('uk-UA', { day: 'numeric', month: 'long', year: 'numeric' })}</div>
    <div>${age} років</div>
  `;
  card.appendChild(info);

  return card;
}

function updateSlider() {
  document.getElementById('slides-container').style.transform = `translateX(-${slideIndex * 100}%)`;
}

function nextSlide() {
  slideIndex = (slideIndex + 1) % slides.length;
  updateSlider();
}

function prevSlide() {
  slideIndex = (slideIndex - 1 + slides.length) % slides.length;
  updateSlider();
}
</script>


</body>
</html>
