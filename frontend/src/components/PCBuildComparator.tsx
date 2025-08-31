import React, { useState, useEffect } from 'react';
import { Search, Filter, ChevronDown, ChevronUp, X } from 'lucide-react';
import { PCBuild, PCBuildsAPI } from '../services/api';
import BuildCard from './BuildCard';

const PCBuildComparator: React.FC = () => {
  const [selectedBuild, setSelectedBuild] = useState<PCBuild | null>(null);
  const [ourBuilds, setOurBuilds] = useState<PCBuild[]>([]);
  const [comparisonBuilds, setComparisonBuilds] = useState<PCBuild[]>([]);
  const [showBuildSelector, setShowBuildSelector] = useState(false);
  const [comparisonType, setComparisonType] = useState<'price' | 'specs' | null>(null);
  const [loading, setLoading] = useState(false);

  const api = new PCBuildsAPI();

  useEffect(() => {
    loadOurBuilds();
  }, []);

  const loadOurBuilds = async () => {
    try {
      const builds = await api.getOurBuilds();
      setOurBuilds(builds);
    } catch (error) {
      console.error('Failed to load builds:', error);
    }
  };

  const selectBuild = (build: PCBuild) => {
    setSelectedBuild(build);
    setShowBuildSelector(false);
    setComparisonBuilds([]);
    setComparisonType(null);
  };

  const compareByPrice = async () => {
    if (!selectedBuild) return;
    
    setLoading(true);
    setComparisonType('price');
    try {
      const builds = await api.compareByPrice(selectedBuild.id);
      setComparisonBuilds(builds);
    } catch (error) {
      console.error('Comparison failed:', error);
    } finally {
      setLoading(false);
    }
  };

  const compareBySpecs = async () => {
    if (!selectedBuild) return;
    
    setLoading(true);
    setComparisonType('specs');
    try {
      const builds = await api.compareBySpecs(selectedBuild.id);
      setComparisonBuilds(builds);
    } catch (error) {
      console.error('Comparison failed:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-black text-white">
      {/* Header */}
      <header className="border-b border-gray-800 p-6">
        <div className="max-w-7xl mx-auto">
          <h1 className="text-3xl font-bold bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
            VA-PC Build Comparator
          </h1>
          <p className="text-gray-400 mt-2">
            Сравнение компьютерных сборок из VK Market
          </p>
        </div>
      </header>

      {/* Main content */}
      <main className="max-w-7xl mx-auto p-6">
        {/* Selected build */}
        <div className="mb-8">
          {!selectedBuild ? (
            <div 
              className="border-2 border-dashed border-gray-700 rounded-lg p-12 text-center cursor-pointer hover:border-purple-500 transition-colors"
              onClick={() => setShowBuildSelector(true)}
            >
              <div className="text-gray-500 mb-4">
                <svg width="64" height="64" viewBox="0 0 24 24" fill="currentColor" className="mx-auto">
                  <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm5 11h-4v4h-2v-4H7v-2h4V7h2v4h4v2z"/>
                </svg>
              </div>
              <p className="text-xl text-gray-400">Выберите ПК для сравнения</p>
              <p className="text-sm text-gray-600 mt-2">Нажмите, чтобы выбрать из наших сборок</p>
            </div>
          ) : (
            <div className="flex justify-center">
              <div className="w-96">
                <BuildCard build={selectedBuild} variant="main" />
                
                {/* Comparison buttons */}
                <div className="mt-6 space-y-3">
                  <button
                    onClick={compareByPrice}
                    className="w-full bg-purple-600 hover:bg-purple-700 text-white font-bold py-3 px-6 rounded-lg transition-colors"
                  >
                    Сравнить с другими ТОЛЬКО по цене
                  </button>
                  
                  <button
                    onClick={compareBySpecs}
                    className="w-full bg-purple-600 hover:bg-purple-700 text-white font-bold py-3 px-6 rounded-lg transition-colors"
                  >
                    Сравнить с другими ТОЛЬКО по CPU + GPU
                  </button>

                  <button
                    onClick={() => {
                      setSelectedBuild(null);
                      setComparisonBuilds([]);
                      setComparisonType(null);
                    }}
                    className="w-full bg-gray-800 hover:bg-gray-700 text-gray-400 py-3 px-6 rounded-lg transition-colors"
                  >
                    Выбрать другую сборку
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Comparison results */}
        {comparisonType && (
          <div className="mt-12">
            <h2 className="text-2xl font-bold mb-6">
              {comparisonType === 'price' 
                ? `Сборки в диапазоне ±50,000 руб. от ${selectedBuild?.price_formatted}`
                : `Сборки с ${selectedBuild?.cpu} + ${selectedBuild?.gpu}`
              }
            </h2>

            {loading ? (
              <div className="text-center py-12">
                <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-purple-500"></div>
                <p className="mt-4 text-gray-400">Загрузка...</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
                {comparisonBuilds.map(build => (
                  <BuildCard 
                    key={build.id} 
                    build={build}
                    variant="comparison"
                  />
                ))}
              </div>
            )}

            {!loading && comparisonBuilds.length === 0 && (
              <div className="text-center py-12 text-gray-500">
                Не найдено подходящих сборок для сравнения
              </div>
            )}
          </div>
        )}
      </main>

      {/* Build selector modal */}
      {showBuildSelector && (
        <div className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center p-6 z-50">
          <div className="bg-gray-900 rounded-lg max-w-6xl w-full max-h-[80vh] overflow-hidden">
            <div className="p-6 border-b border-gray-800 flex justify-between items-center">
              <h2 className="text-2xl font-bold">Выберите сборку VA-PC</h2>
              <button
                onClick={() => setShowBuildSelector(false)}
                className="text-gray-400 hover:text-white"
              >
                <X size={24} />
              </button>
            </div>
            
            <div className="p-6 overflow-y-auto max-h-[calc(80vh-100px)]">
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {ourBuilds.map(build => (
                  <BuildCard 
                    key={build.id}
                    build={build}
                    variant="comparison"
                    onClick={() => selectBuild(build)}
                  />
                ))}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default PCBuildComparator;
