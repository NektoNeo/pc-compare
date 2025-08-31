import React, { useState } from 'react';
import { ChevronDown, ChevronUp } from 'lucide-react';
import { PCBuild } from '../services/api';

interface BuildCardProps {
  build: PCBuild;
  variant?: 'main' | 'comparison';
  onClick?: () => void;
}

const BuildCard: React.FC<BuildCardProps> = ({ build, variant = 'comparison', onClick }) => {
  const [showDescription, setShowDescription] = useState(false);

  const getPriceLabel = () => {
    if (!build.price_comparison) return null;
    
    switch (build.price_comparison) {
      case 'cheaper':
        return (
          <span className="absolute top-2 right-2 bg-green-500 text-white px-3 py-1 rounded-full text-sm font-bold">
            ДЕШЕВЛЕ
          </span>
        );
      case 'more_expensive':
        return (
          <span className="absolute top-2 right-2 bg-red-500 text-white px-3 py-1 rounded-full text-sm font-bold">
            ДОРОЖЕ
          </span>
        );
      default:
        return null;
    }
  };

  const cardClass = variant === 'main' 
    ? 'border-4 border-purple-500 shadow-2xl scale-105'
    : 'border-2 border-gray-700 hover:border-purple-400 transition-all cursor-pointer';

  return (
    <div 
      className={`bg-gray-900 rounded-lg overflow-hidden relative ${cardClass}`}
      onClick={onClick}
    >
      {getPriceLabel()}
      
      {/* Image */}
      <div className="h-48 bg-gray-800 flex items-center justify-center">
        {build.photo_url ? (
          <img 
            src={build.photo_url} 
            alt={build.title}
            className="h-full w-full object-cover"
          />
        ) : (
          <div className="text-gray-600">
            <svg width="64" height="64" viewBox="0 0 24 24" fill="currentColor">
              <path d="M20 2H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h6l2 3 2-3h6c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z"/>
            </svg>
          </div>
        )}
      </div>

      {/* Info */}
      <div className="p-4">
        <h3 className="text-lg font-bold text-white mb-2">{build.company}</h3>
        
        <div className="space-y-1 text-sm">
          <div className="text-gray-400">
            CPU: <span className="text-white font-mono">{build.cpu}</span>
          </div>
          <div className="text-gray-400">
            GPU: <span className="text-white font-mono">{build.gpu}</span>
          </div>
          <div className="text-gray-400">
            RAM: <span className="text-white font-mono">{build.ram}</span>
          </div>
          {build.case_color && (
            <div className="text-gray-400">
              Корпус: <span className="text-white">{build.case_color === 'white' ? 'Белый' : 'Черный'}</span>
            </div>
          )}
        </div>

        <div className="mt-4 text-2xl font-bold text-green-400">
          {build.price_formatted}
        </div>

        {variant === 'main' && (
          <>
            <button
              onClick={(e) => {
                e.stopPropagation();
                setShowDescription(!showDescription);
              }}
              className="mt-4 w-full bg-gray-800 hover:bg-gray-700 text-white py-2 px-4 rounded flex items-center justify-center gap-2"
            >
              Показать описание
              {showDescription ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
            </button>

            {showDescription && (
              <div className="mt-4 p-4 bg-gray-800 rounded text-gray-300 text-sm max-h-48 overflow-y-auto">
                {build.description}
              </div>
            )}
          </>
        )}

        {variant === 'comparison' && (
          <a 
            href={build.vk_url}
            target="_blank"
            rel="noopener noreferrer"
            className="mt-4 inline-block text-purple-400 hover:text-purple-300 text-sm"
            onClick={(e) => e.stopPropagation()}
          >
            Открыть в VK →
          </a>
        )}
      </div>
    </div>
  );
};

export default BuildCard;
