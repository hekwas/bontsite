const priceData = {
  RON: { hubMo: 50, hubLife: 60, miniLife: 35, sym: 'LEI' },
  EUR: { hubMo: 10, hubLife: 12, miniLife: 7, sym: '€' },
  USD: { hubMo: 11, hubLife: 13, miniLife: 8, sym: '$' }
};

function setCurrency(curr) {
  document.querySelectorAll('.currency-btn').forEach(btn => btn.classList.remove('active'));
  const activeBtn = event.currentTarget;
  activeBtn.classList.add('active');

  const elements = document.querySelectorAll('.price-val, .currency-symbol');
  
  const vHubMo = document.querySelector('.val-hub-mo');
  const vHubLife = document.querySelector('.val-hub-life');
  const vMiniLife = document.querySelector('.val-mini-life');
  
  if(vHubMo) vHubMo.innerText = priceData[curr].hubMo;
  if(vHubLife) vHubLife.innerText = priceData[curr].hubLife;
  if(vMiniLife) vMiniLife.innerText = priceData[curr].miniLife;
  
  document.querySelectorAll('.currency-symbol').forEach(el => el.innerText = priceData[curr].sym);
  
  // Fast UI snap feedback
  elements.forEach(el => {
    el.style.opacity = 0.5;
    setTimeout(() => el.style.opacity = 1, 50);
  });
}
